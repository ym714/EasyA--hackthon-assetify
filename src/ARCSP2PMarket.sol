// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ARCSToken.sol";

contract ARCSP2PMarket {
    // ------------------------------------------------
    //                 DATA STRUCTURES
    // ------------------------------------------------

    // Basic order structure.
    struct Order {
        uint256 id;      // Unique order id
        address maker;   // Who created the order
        uint256 price;   // Price in USDC per ARCS token
        uint256 amount;  // Total amount of ARCS tokens in the order
        uint256 filled;  // How many tokens have been traded so far
        bool isActive;   // Whether the order is still active
    }

    // Separate arrays for buy and sell orders.
    Order[] public buyOrders;
    Order[] public sellOrders;

    // Incrementing order IDs.
    uint256 public nextBuyOrderId;
    uint256 public nextSellOrderId;

    // Token contracts for trading.
    ARCSToken public arcsToken;  // Token being traded
    IERC20 public usdcToken;     // Stablecoin used for settlement

    // ------------------------------------------------
    //                     EVENTS
    // ------------------------------------------------

    event BuyOrderCreated(uint256 indexed orderId, address indexed maker, uint256 price, uint256 amount);
    event SellOrderCreated(uint256 indexed orderId, address indexed maker, uint256 price, uint256 amount);
    event OrderFilled(
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        address indexed buyer,
        address seller,
        uint256 tradePrice,
        uint256 amountFilled
    );
    event OrderCancelled(uint256 indexed orderId, bool isBuy);

    // ------------------------------------------------
    //                   CONSTRUCTOR
    // ------------------------------------------------

    constructor(address _arcsToken, address _usdcToken) {
        arcsToken = ARCSToken(_arcsToken);
        usdcToken = IERC20(_usdcToken);
    }

    // ------------------------------------------------
    //             CREATE / CANCEL ORDERS
    // ------------------------------------------------

    /**
     * @notice Creates a buy order.
     * @param _price The bid price in USDC per ARCS token.
     * @param _amount How many ARCS tokens to buy.
     *
     * The buyer must approve this contract to spend (price * amount) USDC before calling.
     */
    function createBuyOrder(uint256 _price, uint256 _amount) external returns (uint256) {
        require(_price > 0, "Price cannot be zero");
        require(_amount > 0, "Amount cannot be zero");

        // Transfer USDC from the buyer to escrow.
        uint256 totalCost = _price * _amount;
        require(usdcToken.transferFrom(msg.sender, address(this), totalCost), "USDC transfer failed");

        // Create and store the buy order.
        buyOrders.push(Order({
            id: nextBuyOrderId,
            maker: msg.sender,
            price: _price,
            amount: _amount,
            filled: 0,
            isActive: true
        }));

        emit BuyOrderCreated(nextBuyOrderId, msg.sender, _price, _amount);
        nextBuyOrderId++;
        return nextBuyOrderId - 1;
    }

    /**
     * @notice Creates a sell order.
     * @param _price The ask price in USDC per ARCS token.
     * @param _amount How many ARCS tokens to sell.
     *
     * The seller must approve this contract to spend `_amount` ARCS tokens before calling.
     */
    function createSellOrder(uint256 _price, uint256 _amount) external returns (uint256) {
        require(_price > 0, "Price cannot be zero");
        require(_amount > 0, "Amount cannot be zero");

        // Transfer ARCS tokens from the seller to escrow.
        require(arcsToken.transferFrom(msg.sender, address(this), _amount), "ARCS transfer failed");

        // Create and store the sell order.
        sellOrders.push(Order({
            id: nextSellOrderId,
            maker: msg.sender,
            price: _price,
            amount: _amount,
            filled: 0,
            isActive: true
        }));

        emit SellOrderCreated(nextSellOrderId, msg.sender, _price, _amount);
        nextSellOrderId++;
        return nextSellOrderId - 1;
    }

    /**
     * @notice Cancels an active order (buy or sell) and refunds the unfilled amount.
     * @param _orderId The ID of the order.
     * @param _isBuy True if the order is a buy order; false if it is a sell order.
     */
    function cancelOrder(uint256 _orderId, bool _isBuy) external {
        if (_isBuy) {
            require(_orderId < buyOrders.length, "Invalid buy order id");
            Order storage order = buyOrders[_orderId];
            require(order.isActive, "Order not active");
            require(order.maker == msg.sender, "Only maker can cancel");

            uint256 unfilled = order.amount - order.filled;
            if (unfilled > 0) {
                // Refund USDC for the unfilled amount.
                uint256 refund = order.price * unfilled;
                usdcToken.transfer(order.maker, refund);
            }
            order.isActive = false;
            emit OrderCancelled(_orderId, true);
        } else {
            require(_orderId < sellOrders.length, "Invalid sell order id");
            Order storage order = sellOrders[_orderId];
            require(order.isActive, "Order not active");
            require(order.maker == msg.sender, "Only maker can cancel");

            uint256 unfilled = order.amount - order.filled;
            if (unfilled > 0) {
                // Refund ARCS tokens for the unfilled amount.
                arcsToken.transfer(order.maker, unfilled);
            }
            order.isActive = false;
            emit OrderCancelled(_orderId, false);
        }
    }

    // ------------------------------------------------
    //                 MATCHING LOGIC
    // ------------------------------------------------

    /**
     * @notice Matches a specified buy order with a sell order for a given amount.
     * @param _buyOrderId The buy order's id.
     * @param _sellOrderId The sell order's id.
     * @param _amount The amount of ARCS tokens to fill.
     *
     * This function requires that the buy order price is at least the sell order price.
     */
    function matchOrders(
        uint256 _buyOrderId,
        uint256 _sellOrderId,
        uint256 _amount
    ) external {
        require(_buyOrderId < buyOrders.length, "Invalid buy order id");
        require(_sellOrderId < sellOrders.length, "Invalid sell order id");

        Order storage buyOrder = buyOrders[_buyOrderId];
        Order storage sellOrder = sellOrders[_sellOrderId];

        require(buyOrder.isActive, "Buy order not active");
        require(sellOrder.isActive, "Sell order not active");

        uint256 buyRemaining = buyOrder.amount - buyOrder.filled;
        uint256 sellRemaining = sellOrder.amount - sellOrder.filled;
        uint256 fillAmount = _min(_amount, _min(buyRemaining, sellRemaining));
        require(fillAmount > 0, "Nothing to fill");

        require(buyOrder.price >= sellOrder.price, "Prices do not cross");

        // Set the trade price to the sell order's price.
        uint256 tradePrice = sellOrder.price;

        // Transfer ARCS tokens from escrow to buyer.
        arcsToken.transfer(buyOrder.maker, fillAmount);

        // Transfer USDC from escrow to seller.
        uint256 cost = tradePrice * fillAmount;
        usdcToken.transfer(sellOrder.maker, cost);

        // Update order fill amounts.
        buyOrder.filled += fillAmount;
        sellOrder.filled += fillAmount;

        // Mark orders inactive if completely filled.
        if (buyOrder.filled == buyOrder.amount) {
            buyOrder.isActive = false;
        }
        if (sellOrder.filled == sellOrder.amount) {
            sellOrder.isActive = false;
        }

        emit OrderFilled(_buyOrderId, _sellOrderId, buyOrder.maker, sellOrder.maker, tradePrice, fillAmount);
    }

    /**
     * @notice Automatically matches orders from the buy and sell order books.
     *
     * For each active buy order, it scans for matching sell orders where the buy price
     * is at least the sell price. Partial fills are allowed.
     *
     * @dev This simple implementation iterates through all orders, which may be gas-expensive.
     */
    function autoMatchOrders() external {
        for (uint256 i = 0; i < buyOrders.length; i++) {
            Order storage buyOrder = buyOrders[i];
            if (!buyOrder.isActive) continue; // Skip inactive buy orders

            // For each buy order, scan through sell orders.
            for (uint256 j = 0; j < sellOrders.length; j++) {
                Order storage sellOrder = sellOrders[j];
                if (!sellOrder.isActive) continue; // Skip inactive sell orders

                // Check if the orders can be matched.
                if (buyOrder.price >= sellOrder.price) {
                    uint256 buyRemaining = buyOrder.amount - buyOrder.filled;
                    uint256 sellRemaining = sellOrder.amount - sellOrder.filled;
                    uint256 fillAmount = _min(buyRemaining, sellRemaining);
                    if (fillAmount == 0) continue;

                    uint256 tradePrice = sellOrder.price;

                    // Transfer ARCS tokens from escrow to the buyer.
                    arcsToken.transfer(buyOrder.maker, fillAmount);

                    // Transfer USDC from escrow to the seller.
                    uint256 cost = tradePrice * fillAmount;
                    usdcToken.transfer(sellOrder.maker, cost);

                    // Update the filled amounts.
                    buyOrder.filled += fillAmount;
                    sellOrder.filled += fillAmount;

                    // Mark orders inactive if fully filled.
                    if (buyOrder.filled == buyOrder.amount) {
                        buyOrder.isActive = false;
                    }
                    if (sellOrder.filled == sellOrder.amount) {
                        sellOrder.isActive = false;
                    }

                    emit OrderFilled(buyOrder.id, sellOrder.id, buyOrder.maker, sellOrder.maker, tradePrice, fillAmount);

                    // If the current buy order is completely filled, stop processing it.
                    if (!buyOrder.isActive) {
                        break;
                    }
                }
            }
        }
    }

    // ------------------------------------------------
    //            UTILITY & HELPER FUNCTIONS
    // ------------------------------------------------

    // Returns the minimum of two numbers.
    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    // Returns the minimum of three numbers.
    function _min(uint256 a, uint256 b, uint256 c) private pure returns (uint256) {
        return _min(_min(a, b), c);
    }

    // ------------------------------------------------
    //                VIEW FUNCTIONS
    // ------------------------------------------------

    /**
     * @notice Returns all buy orders.
     * @dev For production, consider pagination or off-chain indexing.
     */
    function getBuyOrders() external view returns (Order[] memory) {
        return buyOrders;
    }

    /**
     * @notice Returns all sell orders.
     * @dev For production, consider pagination or off-chain indexing.
     */
    function getSellOrders() external view returns (Order[] memory) {
        return sellOrders;
    }

    /**
     * @notice Returns the unfilled portion of a given order.
     * @param _orderId The order id.
     * @param _isBuy True for a buy order; false for a sell order.
     */
    function remaining(uint256 _orderId, bool _isBuy) external view returns (uint256) {
        if (_isBuy) {
            require(_orderId < buyOrders.length, "Invalid buy order id");
            Order memory order = buyOrders[_orderId];
            return order.amount - order.filled;
        } else {
            require(_orderId < sellOrders.length, "Invalid sell order id");
            Order memory order = sellOrders[_orderId];
            return order.amount - order.filled;
        }
    }
}
