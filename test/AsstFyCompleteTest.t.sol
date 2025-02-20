// forge script script/TrySituation.s.sol --tc TrySituation --rpc-url http://127.0.0.1:8545
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// ========== Foundry Imports ==========
import "forge-std/Script.sol";
import "forge-std/Test.sol";

// ========== OpenZeppelin ERC20 ==========
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ========== Uniswap V2 Router Interface ==========
import "../src/interfaces/IUniswapV2.sol";

// ========== Your Main Contract & Token ==========
import "../src/ARCSMarket.sol"; // The updated AssetfyMarket (ARCSMarket) contract with ProjectStatus & ProtocolConfig.

/**
 * @dev A simple ERC20 using OpenZeppelin, for demonstration.
 *      We'll deploy two of these: one to mimic "USDC" and one as a "TestToken".
 */
contract TestToken is ERC20 {
    constructor(string memory name_, string memory symbol_, uint256 initialSupply)
        ERC20(name_, symbol_)
    {
        _mint(msg.sender, initialSupply);
    }
}


/**
 * @title TrySituation
 * @notice Foundry script to simulate end-to-end usage of the AssetfyMarket contract.
 */
contract TrySituation is Script, Test {
    // ------------------------------------------------
    // Addresses & Private Keys
    // ------------------------------------------------
    address deployer  = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;  
    address company   = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;  
    address investor1 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;  
    address investor2 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    uint256 deployerKey  = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 companyKey   = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 investor1Key = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 investor2Key = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;

    // ------------------------------------------------
    // Uniswap addresses (local or testnet)
    // ------------------------------------------------
    address uniswapFactory = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address uniswapRouter  = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;

    // ------------------------------------------------
    // Contracts Deployed in This Script
    // ------------------------------------------------
    AssetfyMarket             public asstFy;   // The main contract
    TestToken          public testUSDC; // "USDC" stand-in
    TestToken          public testToken;
    IUniswapV2Router01 public router;

    function run() external {
        // Label addresses for clarity in debug traces
        vm.label(deployer,  "DEPLOYER");
        vm.label(company,   "COMPANY");
        vm.label(investor1, "INVESTOR1");
        vm.label(investor2, "INVESTOR2");
        vm.label(uniswapFactory, "UNISWAP_FACTORY");
        vm.label(uniswapRouter,  "UNISWAP_ROUTER");

        // Start broadcasting from the "deployer" account
        vm.startBroadcast(deployerKey);

        // ---------------------------
        // 1. Deploy Test Tokens
        // ---------------------------
        // Mint 1,000,000 (with 1e18 decimals => total = 1e24) for each token.
        testUSDC = new TestToken("TestUSDC", "USDC", 2_000_000e18); // 2 million USDC
        vm.label(address(testUSDC), "TestUSDC");
        console2.log("TestUSDC deployed at:", address(testUSDC));

        testToken = new TestToken("TestToken", "TST", 1_000_000e18); // 1 million TST
        vm.label(address(testToken), "TestToken");
        console2.log("TestToken deployed at:", address(testToken));

        // ---------------------------
        // 2. Deploy AssetfyMarket with ProtocolConfig
        // ---------------------------
        // Example config: protocol fee = 20 bps (0.2%), earlyRedemptionRate = 10% annual
        AssetfyMarket.ProtocolConfig memory configData = AssetfyMarket.ProtocolConfig({
            protocolFeeBps: 20,
            earlyRedemptionRate: 10
        });

        asstFy = new AssetfyMarket(
            address(testUSDC),
            deployer,
            uniswapRouter,
            configData
        );
        vm.label(address(asstFy), "AsstFyContract");
        console2.log("AssetfyMarket deployed at:", address(asstFy));

        // Whitelist "testToken" for ERC20 investment
        asstFy.updateWhitelist(address(testToken), true);

        // ---------------------------
        // 3. Distribute tokens
        // ---------------------------
        // Give the company & investors some "USDC"
        testUSDC.transfer(company,   100_000e18);
        testUSDC.transfer(investor1, 100_000e18);
        testUSDC.transfer(investor2, 100_000e18);

        // Give investor1 and investor2 TST
        testToken.transfer(investor1, 50_000e18);

        // *** IMPORTANT FIX ***
        // Increase Investor2's TST from 50k to 100k to avoid "InsufficientBalance" errors
        testToken.transfer(investor2, 100_000e18);

        // ---------------------------
        // 4. Create a Uniswap Pool for TST <-> USDC
        // ---------------------------
        router = IUniswapV2Router01(uniswapRouter);

        // Approve router to pull large amounts for liquidity
        testUSDC.approve(address(router), 500_000e18);
        testToken.approve(address(router), 500_000e18);

        // 4a. Add TST-USDC liquidity
        router.addLiquidity(
            address(testUSDC),
            address(testToken),
            100_000e18,  // USDC amount
            100_000e18,  // TST amount
            100_000e18,  // min USDC
            100_000e18,  // min TST
            deployer,    // LP recipient
            block.timestamp
        );
        console2.log("start addLiquidityETH");

        // 4b. Add USDC-ETH liquidity
        testUSDC.approve(address(router), 100_000e18);
        router.addLiquidityETH{ value: 10 ether }(
            address(testUSDC),
            100_000e18, // amountTokenDesired
            0,          // amountTokenMin
            0,          // amountETHMin
            deployer,
            block.timestamp
        );
        console2.log("Liquidity added for USDC <-> TST and USDC <-> ETH on Uniswap.");

        vm.stopBroadcast(); // Done with "deployer"

        // ---------------------------
        // 5. Company creates project
        // ---------------------------
        vm.startBroadcast(companyKey);
        // Maturity in 365 days
        uint256 maturityTime = block.timestamp + 365 days;

        uint256 projectId = asstFy.createProject(
            "TestProject", 
            "Raising funds for next product", 
            10_000e18,  // target in USDC
            10,         // 10% interest
            maturityTime
        );
        console2.log("Project created by company. projectId =", projectId);

        // Try to issueToken as company => revert (only owner can issue)
        console2.log("Expect revert if non-owner calls issueToken:");
        vm.expectRevert("Not platform owner");
        asstFy.issueToken(projectId);

        vm.stopBroadcast();

        // ---------------------------
        // 6. Owner (deployer) issues token
        // ---------------------------
        vm.startBroadcast(deployerKey);
        asstFy.issueToken(projectId);
        console2.log("Owner issued ARCS token for projectId =", projectId);
        vm.stopBroadcast();

        // ---------------------------
        // 7. Investor1 invests ETH
        // ---------------------------
        vm.startBroadcast(investor1Key);
        console2.log("Investor1 invests 1 ETH => TST => USDC => invests in project");
        asstFy.investETH{value: 1 ether}(projectId);

        // Revert test: 0 ETH
        console2.log("Expect revert with 0 ETH");
        vm.expectRevert("No ETH sent");
        asstFy.investETH{value: 0}(projectId);

        vm.stopBroadcast();

        // ---------------------------
        // 8. Investor2 invests TST
        // ---------------------------
        vm.startBroadcast(investor2Key);

        // Approve AssetfyMarket to pull TST
        testToken.approve(address(asstFy), 30_000e18);
        console2.log("Investor2 invests 5,000 TST => swapped to USDC => invests in project");
        asstFy.investERC20(projectId, address(testToken), 5_000e18);

        // Revert test: unwhitelisted token => revert
        console2.log("Expect revert with unwhitelisted token");
        vm.expectRevert("Token not whitelisted");
        asstFy.investERC20(projectId, address(0x9999), 1000e18);

        // ---------------------------
        // 9. Overfund scenario
        // ---------------------------
        console2.log("Investor2 invests 20,000 TST => likely over the 10k USDC target => partial acceptance + refund");
        asstFy.investERC20(projectId, address(testToken), 20_000e18);

        vm.stopBroadcast();

        // Project should be TARGET_REACHED if it exceeded 10k USDC

        // ---------------------------
        // 10. releaseFunds by company
        // ---------------------------
        vm.startBroadcast(companyKey);

        console2.log("Company calls releaseFunds => should transition to FUNDS_RELEASED");
        try asstFy.releaseFunds(projectId) {
            console2.log("Funds released successfully.");
        } catch Error(string memory reason) {
            console2.log("releaseFunds reverted => reason =", reason);
        }

        // ---------------------------
        // 11. Partial repayment
        // ---------------------------
        testUSDC.approve(address(asstFy), 5_000e18);
        asstFy.repayment(projectId, 5_000e18);
        console2.log("Company repaid 5,000 USDC to contract.");

        vm.stopBroadcast();

        // ---------------------------
        // 12. Early redeem by investor1
        // ---------------------------
        vm.startBroadcast(investor1Key);
        console2.log("Investor1 tries earlyRedeem for 500 ARCS before maturity");
        try asstFy.earlyRedeem(projectId, 500e18) {
            console2.log("earlyRedeem(500) success");
        } catch Error(string memory reason) {
            console2.log("earlyRedeem(500) reverted => reason =", reason);
        }
        vm.stopBroadcast();

        // ---------------------------
        // 13. Warp to maturity
        // ---------------------------
        console2.log("Warping time +365 days to reach maturity");
        vm.warp(maturityTime + 1);

        // ---------------------------
        // 14. Final repayment by company
        // ---------------------------
        vm.startBroadcast(companyKey);
        testUSDC.approve(address(asstFy), 10_000e18);
        asstFy.repayment(projectId, 10_000e18);
        console2.log("Company final repayment 10,000 USDC.");
        vm.stopBroadcast();

        // ---------------------------
        // 15. Post-maturity redeem by investor2
        // ---------------------------
        vm.startBroadcast(investor2Key);
        console2.log("Investor2 tries redeem(900) after maturity");
        try asstFy.redeem(projectId, 900e18) {
            console2.log("redeem(900) success");
        } catch Error(string memory reason) {
            console2.log("redeem(900) reverted => reason =", reason);
        }

        console2.log("Expect revert if investor2 redeems more ARCS than they hold");
        vm.expectRevert();
        asstFy.redeem(projectId, 1000e18);

        vm.stopBroadcast();

        console2.log("== TrySituation Script Completed Successfully ==");
    }
}
