pragma solidity ^0.8.17;

import "./ARCSToken.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2.sol";
import "./lib/EarlyRedempitionLib.sol";

contract AssetfyMarket {
    enum ProjectStatus {
        OPEN,
        TARGET_REACHED,
        FUNDS_RELEASED,
        CLOSED
    }

    struct ProtocolConfig {
        uint256 protocolFeeBps;
        uint256 earlyRedemptionRate;
    }

    ProtocolConfig public config;

    address public owner;
    IERC20 public usdc;
    address public uniswapRouter;

    mapping(address => bool) public tokenWhitelist;

    struct Project {
        uint256 id;
        address company;
        string name;
        string description;

        uint256 targetAmount;
        uint256 interestRate;
        uint256 maturityTime;
        uint256 totalInvested;

        ARCSToken ARCSToken;
        uint256 totalRepaid;

        ProjectStatus status;
    }

    uint256 public latestProjectId;
    mapping(uint256 => Project) public projects;

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed company,
        string name,
        uint256 targetAmount
    );
    event TokenIssued(uint256 indexed projectId, address tokenAddress);
    event Invested(uint256 indexed projectId, address indexed investor, uint256 usdcAmount);
    event EarlyRedeemed(uint256 indexed projectId, address indexed investor, uint256 discountedUSDC);
    event Redeemed(uint256 indexed projectId, address indexed investor, uint256 redemptionUSDC);
    event Repaid(uint256 indexed projectId, address indexed company, uint256 amountUSDC);
    event FundsReleased(uint256 indexed projectId, uint256 releasedAmountUSDC);

    constructor(address _usdc,address _owner, address _uniswapRouter,ProtocolConfig memory _config) {
        owner = _owner;
        usdc = IERC20(_usdc);
        uniswapRouter = _uniswapRouter;
        config = _config;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not platform owner");
        _;
    }

    modifier onlyCompany(uint256 _projectId) {
        require(msg.sender == projects[_projectId].company, "Not project owner");
        _;
    }

    function updateWhitelist(address _token, bool _isAllowed) external onlyOwner {
        tokenWhitelist[_token] = _isAllowed;
    }

    function createProject(
        string calldata _name,
        string calldata _description,
        uint256 _targetAmount,
        uint256 _interestRate,
        uint256 _maturityTime
    ) external returns (uint256) 
    {
        require(_maturityTime > block.timestamp, "Maturity must be in the future");
        require(_targetAmount > 0, "Target amount must be > 0");

        latestProjectId++;
        Project storage p = projects[latestProjectId];
        p.id = latestProjectId;
        p.company = msg.sender;
        p.name = _name;
        p.description = _description;
        p.targetAmount = _targetAmount;
        p.interestRate = _interestRate;
        p.maturityTime = _maturityTime;
        p.totalInvested = 0;
        p.totalRepaid = 0;
        p.status = ProjectStatus.OPEN;

        emit ProjectCreated(latestProjectId, msg.sender, _name, _targetAmount);
        return latestProjectId;
    }

    function issueToken(uint256 _projectId) external onlyOwner {
        Project storage p = projects[_projectId];
        require(address(p.ARCSToken) == address(0), "Token already issued");
        require(p.status == ProjectStatus.OPEN, "Project not active");

        string memory tokenName = string(
            abi.encodePacked("ARCS-", p.name, "-", _uintToString(p.maturityTime))
        );
        string memory tokenSymbol = string(
            abi.encodePacked("ARCS-", _uintToString(p.maturityTime))
        );

        ARCSToken token = new ARCSToken(
            tokenName,
            tokenSymbol,
            address(this),
            p.maturityTime
        );
        p.ARCSToken = token;

        emit TokenIssued(_projectId, address(token));
    }

    function investETH(uint256 _projectId) external payable {
        uint256 ethAmount = msg.value;
        require(ethAmount > 0, "No ETH sent");
        _investETH(_projectId, ethAmount);
    }

    function investERC20(uint256 _projectId, address _token, uint256 _amount) external {
        require(_amount > 0, "No tokens sent");
        require(tokenWhitelist[_token], "Token not whitelisted");

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        IERC20(_token).approve(uniswapRouter, _amount);

        uint256 usdcReceived = _swapTokenForUSDC(_token, _amount);

        _completeInvestment(_projectId, usdcReceived);
    }

    function _investETH(uint256 _projectId, uint256 _amount) internal {
        uint256 usdcReceived = _swapETHForUSDC(_amount);

        _completeInvestment(_projectId, usdcReceived);
    }

    function _completeInvestment(uint256 _projectId, uint256 _usdcAmount) internal {
        Project storage p = projects[_projectId];
        require(p.status == ProjectStatus.OPEN, "Project not accepting investments");
        require(address(p.ARCSToken) != address(0), "ARCS token not issued yet");
        require(_usdcAmount > 0, "No USDC from swap");

        uint256 fee = (_usdcAmount * config.protocolFeeBps) / 10000; 
        uint256 netAmount = _usdcAmount - fee;

        if (fee > 0) {
            usdc.transfer(owner, fee);
        }

        uint256 newTotal = p.totalInvested + netAmount;
        uint256 acceptedAmount = netAmount;

        if (newTotal > p.targetAmount) {
            acceptedAmount = p.targetAmount - p.totalInvested;
        }

        p.totalInvested += acceptedAmount;

        p.ARCSToken.mint(msg.sender, acceptedAmount);

        if (acceptedAmount < netAmount) {
            uint256 refundAmount = netAmount - acceptedAmount;
            usdc.transfer(msg.sender, refundAmount);
        }

        if (p.totalInvested >= p.targetAmount) {
            p.status = ProjectStatus.TARGET_REACHED;
        }

        emit Invested(_projectId, msg.sender, acceptedAmount);
    }

    function earlyRedeem(uint256 _projectId, uint256 _ARCSAmount) external {
        Project storage p = projects[_projectId];
        require(block.timestamp < p.maturityTime, "Bond matured; use redeem()");
        require(_ARCSAmount > 0, "Cannot redeem zero");

        // 1. Calculate discounted value owed to investor
        uint256 discountedValue = EarlyRedemptionLib.calculateDiscountedValue(
            p.maturityTime,
            config.earlyRedemptionRate,
            _ARCSAmount,
            block.timestamp
        );

        // 2. Transfer ARCS tokens from investor to owner
        //    Investor must have approved the contract to transfer their ARCS
        p.ARCSToken.transferFrom(msg.sender, owner, _ARCSAmount);

        // 3. Transfer USDC from owner to the investor
        //    The owner must have approved the contract to spend at least discountedValue USDC
        require(
            usdc.allowance(owner, address(this)) >= discountedValue,
            "Not enough USDC allowance from owner"
        );
        usdc.transferFrom(owner, msg.sender, discountedValue);

        emit EarlyRedeemed(_projectId, msg.sender, discountedValue);
    }


    function redeem(uint256 _projectId, uint256 _ARCSAmount) external {
        Project storage p = projects[_projectId];
        require(block.timestamp >= p.maturityTime, "Not matured yet");
        require(_ARCSAmount > 0, "Cannot redeem zero");

        uint256 redemptionPerToken = 1e18 + (p.interestRate * 1e16);
        uint256 redemptionValue = (_ARCSAmount * redemptionPerToken) / 1e18;

        p.ARCSToken.burn(msg.sender, _ARCSAmount);

        require(usdc.balanceOf(address(this)) >= redemptionValue, "Insufficient USDC");
        usdc.transfer(msg.sender, redemptionValue);

        emit Redeemed(_projectId, msg.sender, redemptionValue);
    }

    function repayment(uint256 _projectId, uint256 _amount) external onlyCompany(_projectId) {
        Project storage p = projects[_projectId];
        require(
            p.status == ProjectStatus.OPEN ||
            p.status == ProjectStatus.TARGET_REACHED ||
            p.status == ProjectStatus.FUNDS_RELEASED,
            "Project not active or not issued"
        );

        usdc.transferFrom(msg.sender, address(this), _amount);

        p.totalRepaid += _amount;

        emit Repaid(_projectId, msg.sender, _amount);
    }

    function releaseFunds(uint256 _projectId) external onlyCompany(_projectId) {
        Project storage p = projects[_projectId];
        require(p.status == ProjectStatus.TARGET_REACHED, "Project not ready for release");

        uint256 amount = p.totalInvested;
        require(amount > 0, "No funds to release");

        p.totalInvested = 0;
        p.status = ProjectStatus.FUNDS_RELEASED;

        usdc.transfer(p.company, amount);

        emit FundsReleased(_projectId, amount);
    }

    function _swapTokenForUSDC(address tokenIn, uint256 amountIn) internal returns (uint256) {
        require(amountIn > 0, "No tokens to swap");
        require(tokenIn != address(0), "Invalid token");

        IUniswapV2Router01 router = IUniswapV2Router01(uniswapRouter);

        IERC20(tokenIn).approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = address(usdc);

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        return amounts[amounts.length - 1];
    }

    function _swapETHForUSDC(uint256 _ethAmount) internal returns (uint256) {
        require(_ethAmount > 0, "No ETH provided");

        IUniswapV2Router01 router = IUniswapV2Router01(uniswapRouter);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(usdc);

        uint256[] memory amounts = router.swapExactETHForTokens{value: _ethAmount}(
            0,
            path,
            address(this),
            block.timestamp
        );

        return amounts[amounts.length - 1];
    }

    function _uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(
                uint8(48 + uint256(value % 10))
            );
            value /= 10;
        }
        return string(buffer);
    }
}
