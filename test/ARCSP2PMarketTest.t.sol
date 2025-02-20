// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/ARCSP2PMarket.sol";
import "../src/ARCSToken.sol";

contract TestUSDC is ERC20 {
    constructor() ERC20("Test USDC", "USDC") {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract ARCSP2PMarketTest is Test {
    ARCSP2PMarket public market;
    ARCSToken public arcsToken;
    TestUSDC public usdc;

    address deployer = address(1);
    address seller   = address(2);
    address buyer    = address(3);

    function run() public {
        //----------------------------------------
        // 1. Setup: Deploy & Distribute Tokens
        //----------------------------------------
        vm.startPrank(deployer);

        // Deploy test USDC
        usdc = new TestUSDC();

        // Deploy ARCS token
        arcsToken = new ARCSToken(
            "ARCS Test Token",
            "ARCS",
            deployer,                  // protocol address
            block.timestamp + 365 days // maturity time
        );

        // Deploy market contract
        market = new ARCSP2PMarket(address(arcsToken), address(usdc));

        // Distribute USDC to buyer
        usdc.transfer(buyer, 100_000e18);

        // Mint ARCS to seller
        arcsToken.mint(seller, 100_000e18);

        vm.stopPrank();

        //----------------------------------------
        // 2. Watch Balances After Buy / Sell
        //----------------------------------------
        // Initial balances
        uint256 initialBuyerUSDC   = usdc.balanceOf(buyer);   // 100,000e18
        uint256 initialSellerARCS  = arcsToken.balanceOf(seller); // 100,000e18

        // Create a buy order
        vm.startPrank(buyer);
        uint256 buyPrice   = 1e18;
        uint256 buyAmount  = 1000e18;
        uint256 buyCost    = buyPrice * buyAmount; // 1000 USDC

        // Approve and create
        usdc.approve(address(market), buyCost);
        uint256 buyOrderId = market.createBuyOrder(buyPrice, buyAmount);

        // Check buyer USDC after creating buy order
        // => The contract takes 1000 USDC into escrow
        uint256 buyerUSDCAfterBuy = usdc.balanceOf(buyer);
        assertEq(buyerUSDCAfterBuy, initialBuyerUSDC - buyCost, "Buyer USDC after buy order");
        vm.stopPrank();

        // Create a sell order
        vm.startPrank(seller);
        uint256 sellPrice  = 1e18;
        uint256 sellAmount = 500e18;

        arcsToken.approve(address(market), sellAmount);
        uint256 sellOrderId = market.createSellOrder(sellPrice, sellAmount);

        // Check seller ARCS after creating sell order
        // => 500 ARCS taken into escrow
        uint256 sellerARCSAfterSell = arcsToken.balanceOf(seller);
        assertEq(sellerARCSAfterSell, initialSellerARCS - sellAmount, "Seller ARCS after sell order");
        vm.stopPrank();

        //----------------------------------------
        // 3. Check Fill & Remain (Partial Fill)
        //----------------------------------------
        // Let's partially fill: match 300 out of the 500 on the sell side
        vm.startPrank(buyer);
        market.matchOrders(buyOrderId, sellOrderId, 300e18);
        vm.stopPrank();

        {
            ARCSP2PMarket.Order memory bOrder = market.getBuyOrders()[buyOrderId];
            ARCSP2PMarket.Order memory sOrder = market.getSellOrders()[sellOrderId];

            // Each has 300 filled
            assertEq(bOrder.filled, 300e18, "Buy order filled=300");
            assertEq(sOrder.filled, 300e18, "Sell order filled=300");

            // Both remain active
            assertTrue(bOrder.isActive, "Buy order still active");
            assertTrue(sOrder.isActive, "Sell order still active");

            // Check 'remaining()'
            uint256 buyRem  = market.remaining(buyOrderId, true);
            uint256 sellRem = market.remaining(sellOrderId, false);
            // Buyer had 1000 total => 300 filled => 700 remain
            assertEq(buyRem, 700e18, "Buy remain=700");
            // Seller had 500 total => 300 filled => 200 remain
            assertEq(sellRem, 200e18, "Sell remain=200");
        }

        //----------------------------------------
        // 4. Watch Balances After Match
        //----------------------------------------
        // Let's see how the buyer's/seller's balances changed after that 300 fill.
        //  - Buyer should have spent 300 * 1 USDC = 300
        //  - Buyer gained 300 ARCS
        //  - Seller should have received 300 USDC
        //  - Seller parted with 300 ARCS

        {
            uint256 buyerUSDCNow  = usdc.balanceOf(buyer);
            uint256 buyerARCSNow  = arcsToken.balanceOf(buyer);
            uint256 sellerUSDCNow = usdc.balanceOf(seller);
            uint256 sellerARCSNow = arcsToken.balanceOf(seller);

            // Buyer’s ARCS increased by 300
            assertEq(buyerARCSNow, 300e18, "Buyer gained 300 ARCS");

            // Buyer’s USDC decreased by 300 (escrow had taken 1000, but only 300 actually left escrow so far).
            // Strictly speaking, the buyer's *wallet* after escrow deposit would have 100,000 - 1000 => 99,000
            // Then after partial fill of 300, the buyer doesn't pay anything additional from the wallet 
            // (the USDC was already in escrow). So buyer's wallet is still 99,000. 
            // The seller's wallet got the 300 USDC from escrow.

            // Meanwhile, the seller's USDC increased by 300
            assertEq(sellerUSDCNow, 300e18, "Seller gained 300 USDC");

            // Seller parted with 500 total into escrow; 300 filled => 200 still in escrow, 200 remains to sell
            // So seller’s ARCS in wallet should be 100,000 - 500 = 99,500
            // Because 300 have been transferred to the buyer, and 200 remain in escrow.
            assertEq(sellerARCSNow, 100_000e18 - 500e18, "Seller parted with 500 in escrow, 300 filled, 200 still in escrow");
        }

        // Now fill the remaining 200
        vm.startPrank(buyer);
        market.matchOrders(buyOrderId, sellOrderId, 500e18); 
        // We try 500, but only 200 remain => partial fill of 200
        vm.stopPrank();

        {
            // Final check: seller’s entire 500 is filled => sell order inactive
            ARCSP2PMarket.Order memory bOrder2 = market.getBuyOrders()[buyOrderId];
            ARCSP2PMarket.Order memory sOrder2 = market.getSellOrders()[sellOrderId];

            assertEq(bOrder2.filled, 500e18, "Buyer filled total=500");
            assertEq(sOrder2.filled, 500e18, "Seller filled total=500");
            assertFalse(sOrder2.isActive, "Sell order complete");
            // Buyer might still have 500 unfilled out of 1000 => order isActive
            assertTrue(bOrder2.isActive, "Buyer order partially open");
        }

        //----------------------------------------
        // Final Log
        //----------------------------------------
        emit log("All checks succeeded. Balances, fill amounts, remain checks are verified.");
    }
}
