// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// ========== Foundry Imports ==========
import "forge-std/Script.sol";
import "forge-std/console2.sol";

// ========== OpenZeppelin ERC20 ==========
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ========== Uniswap V2 Router Interface ==========
import "../src/interfaces/IUniswapV2.sol";

// ========== Your Main Contract ==========
import "../src/ARCSMarket.sol"; // The updated AssetfyMarket contract


/**
 * @dev A simple ERC20 using OpenZeppelin, 
 *      used as a stand-in for USDC or any other token.
 */
contract TestToken is ERC20 {
    constructor(
        string memory name_, 
        string memory symbol_, 
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply);
    }
}


/**
 * @title SimpleDeployment
 * @notice Foundry script to deploy:
 *         - Two TestTokens (one acting like USDC)
 *         - The main AssetfyMarket contract
 *         - Set up a Uniswap pool
 */
contract SimpleDeployment is Script {
    // ----------------------------------------------------------------------
    // Addresses & Private Keys (from .env)
    // ----------------------------------------------------------------------
    address deployer;
    uint256 deployerKey;
    address uniswapFactory;
    address uniswapRouter;

    // ----------------------------------------------------------------------
    // Contracts
    // ----------------------------------------------------------------------
    AssetfyMarket       public assetfyMarket;
    TestToken           public testUSDC;      // acts like our "USDC"
    TestToken           public testToken;     // another test token
    IUniswapV2Router01  public router;

    // Example protocol config
    AssetfyMarket.ProtocolConfig public configData;

    function setUp() public {
        // Load environment variables
        deployer = vm.envAddress("DEPLOYER");
        deployerKey = vm.envUint("DEPLOYER_KEY");
        uniswapFactory = vm.envAddress("UNISWAP_FACTORY");
        uniswapRouter = vm.envAddress("UNISWAP_ROUTER");

        // Optional: set the protocol config you want to use
        configData = AssetfyMarket.ProtocolConfig({
            protocolFeeBps: 20,         // e.g. 0.20%
            earlyRedemptionRate: 10     // e.g. 10%
        });
    }

    function run() external {
        // ------------------------------------------------
        // 1. Prepare for broadcasting from your deployer
        // ------------------------------------------------
        vm.startBroadcast(deployerKey);

        // Label for debug/tracing
        vm.label(deployer, "DEPLOYER");
        vm.label(uniswapFactory, "UNISWAP_FACTORY");
        vm.label(uniswapRouter, "UNISWAP_ROUTER");

        // ------------------------------------------------
        // 2. Deploy two test tokens
        //    - testUSDC => used as "USDC"
        //    - testToken => second token
        // ------------------------------------------------
        testUSDC = new TestToken("TestUSDC", "USDC", 2_000_000e18);
        vm.label(address(testUSDC), "TestUSDC");
        console2.log("TestUSDC deployed at:", address(testUSDC));

        testToken = new TestToken("TestToken", "TST", 1_000_000e18);
        vm.label(address(testToken), "TestToken");
        console2.log("TestToken deployed at:", address(testToken));

        // ------------------------------------------------
        // 3. Deploy AssetfyMarket referencing testUSDC
        // ------------------------------------------------
        assetfyMarket = new AssetfyMarket(
            address(testUSDC),
            uniswapRouter,
            configData
        );
        vm.label(address(assetfyMarket), "AssetfyMarket");
        console2.log("AssetfyMarket deployed at:", address(assetfyMarket));

        // ------------------------------------------------
        // 4. Initialize Uniswap Router & add Liquidity
        // ------------------------------------------------
        // We'll demonstrate creating a TST-USDC pair,
        // plus USDC-ETH liquidity as well.

        router = IUniswapV2Router01(uniswapRouter);

        // Approve the router to transfer tokens
        testUSDC.approve(address(router), type(uint256).max);
        testToken.approve(address(router), type(uint256).max);

        // 4a. Add TST <-> USDC liquidity
        uint256 usdcAmount = 100_000e18;
        uint256 tstAmount  = 100_000e18;
        router.addLiquidity(
            address(testUSDC),
            address(testToken),
            usdcAmount,
            tstAmount,
            usdcAmount,  // min USDC
            tstAmount,   // min TST
            deployer,
            block.timestamp
        );
        console2.log("Liquidity added: USDC-TST");

        // 4b. Add USDC <-> ETH liquidity
        uint256 usdcForEthPool = 50_000e18;
        console2.log("Start addLiquidityETH");
        router.addLiquidityETH{ value: 5 ether }(
            address(testUSDC),
            usdcForEthPool, // amountTokenDesired
            0,              // amountTokenMin
            0,              // amountETHMin
            deployer,
            block.timestamp
        );
        console2.log("Liquidity added: USDC-ETH");

        // ------------------------------------------------
        // Done
        // ------------------------------------------------
        vm.stopBroadcast();

        console2.log("== SimpleDeployment Script Completed ==");
        console2.log("Use the above addresses in your system as needed.");
    }
}
