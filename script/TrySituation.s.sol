//forge test --fork-url http://127.0.0.1:8545
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
import "../src/ARCSMarket.sol"; // The updated AssetfyMarket contract with ProjectStatus & ProtocolConfig;


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
 * @notice Foundry script to simulate end-to-end usage of the updated AssetfyMarket contract.
 */
contract TrySituation is Script, Test {
    // ------------------------------------------------
    // Addresses & Private Keys (from your prompt)
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
    // Uniswap addresses (from your prompt)
    // ------------------------------------------------
    address uniswapFactory = 0x7Ae58f10f7849cA6F5fB71b7f45CB416c9204b1e;
    address uniswapRouter  = 0x1689E7B1F10000AE47eBfE339a4f69dECd19F602;

    // ------------------------------------------------
    // Contracts Deployed in This Script
    // ------------------------------------------------
    AssetfyMarket         public asstFy;        // The main contract
    TestToken      public testUSDC;      // "USDC" stand-in
    TestToken      public testToken;     // Another ERC20 for investment
    IUniswapV2Router01 public router;    // For addLiquidity, etc.

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
        testUSDC = new TestToken("TestUSDC", "USDC", 2_000_000e18);
        vm.label(address(testUSDC), "TestUSDC");
        console2.log("TestUSDC deployed at:", address(testUSDC));

        testToken = new TestToken("TestToken", "TST", 1_000_000e18);
        vm.label(address(testToken), "TestToken");
        console2.log("TestToken deployed at:", address(testToken));

        // ---------------------------
        // 2. Deploy AssetfyMarket with ProtocolConfig
        // ---------------------------
        // Example config: 20 bps fee => 0.2%, earlyRedemptionRate => 10% annual
        AssetfyMarket.ProtocolConfig memory configData = AssetfyMarket.ProtocolConfig({
            protocolFeeBps: 20,
            earlyRedemptionRate: 10
        });

        asstFy = new AssetfyMarket(
            address(testUSDC),
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
        // We'll give the company & investors some "USDC"
        testUSDC.transfer(company,   100_000e18);
        testUSDC.transfer(investor1, 100_000e18);
        testUSDC.transfer(investor2, 100_000e18);

        // We'll give the investors some "TST" to invest
        testToken.transfer(investor1, 50_000e18);
        testToken.transfer(investor2, 50_000e18);

        // ---------------------------
        // 4. Create a Uniswap Pool for TST <-> USDC
        // ---------------------------
        router = IUniswapV2Router01(uniswapRouter);

        testUSDC.approve(address(router), 500_000e18);
        testToken.approve(address(router), 500_000e18);

        router.addLiquidity(
            address(testUSDC),
            address(testToken),
            100_000e18,  // USDC amount to add
            100_000e18,  // TST amount to add
            100_000e18,  // USDC min
            100_000e18,  // TST min
            deployer,    // LP tokens recipient
            block.timestamp
        );
        console2.log("start addLiquidityETH");
        // Approve 100,000 USDC
        testUSDC.approve(address(router), 100_000e18);

        // Actually send 10 ETH to the router
        router.addLiquidityETH{ value: 10 ether }(
            address(testUSDC),
            100_000e18, // amountTokenDesired
            0,          // amountTokenMin
            0,          // amountETHMin
            deployer,
            block.timestamp
        );
        console2.log("Liquidity added for USDC <-> TST on Uniswap.");

        vm.stopBroadcast(); // Done with "deployer"

        // ---------------------------
        // 5. Company creates project
        // ---------------------------
        vm.startBroadcast(companyKey);
        // Maturity in exactly 365 days
        uint256 maturityTime = block.timestamp + 365 days;

        uint256 projectId = asstFy.createProject(
            "TestProject", 
            "Raising funds for next product", 
            10_000e18,  // target in USDC
            10,         // interestRate = 10%
            maturityTime
        );
        console2.log("Project created by company. projectId =", projectId);

        // Try to issueToken as company => revert
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
        testToken.approve(address(asstFy), 10_000e18);
        console2.log("Investor2 invests 5000 TST => swapped to USDC => invests in project");
        asstFy.investERC20(projectId, address(testToken), 5_000e18);

        // Revert test: unwhitelisted token => revert
        console2.log("Expect revert with unwhitelisted token");
        vm.expectRevert("Token not whitelisted");
        asstFy.investERC20(projectId, address(0x9999), 1000e18);

        vm.stopBroadcast();

        // // ---------------------------
        // // 9. Overfund scenario
        // // ---------------------------
        // vm.startBroadcast(investor2Key);

        // testToken.approve(address(asstFy), 30_000e18);
        // console2.log("Investor2 invests 20_000 TST => likely over the 10k USDC target => partial acceptance + refund");
        // asstFy.investERC20(projectId, address(testToken), 20_000e18);

        // vm.stopBroadcast();

        // By now, project status should be TARGET_REACHED if it exceeded 10k USDC

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

        vm.stopBroadcast();

        // ---------------------------
        // 11. Partial repayment
        // ---------------------------
        vm.startBroadcast(companyKey);
        testUSDC.approve(address(asstFy), 5_000e18);
        asstFy.repayment(projectId, 5_000e18);
        console2.log("Company repaid 5000 USDC to contract.");
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
        // First try with a valid amount
        console2.log("Investor2 tries redeem(900) after maturity");
        try asstFy.redeem(projectId, 900e18) {
            console2.log("redeem(900) success");
        } catch Error(string memory reason) {
            console2.log("redeem(900) reverted => reason =", reason);
        }

        // Then test the revert case with an amount we know exceeds balance
        console2.log("Expect revert if investor2 redeems more ARCS than they hold");
        vm.expectRevert();
        asstFy.redeem(projectId, 1000e18);

        vm.stopBroadcast();

        console2.log("== TrySituation Script Completed Successfully ==");
    }
}
