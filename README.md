# AssetfyMarket

## What is Assetfy?
Assetfy is a decentralized funding platform that bridges startups seeking capital with investors through secure, blockchain-based solutions. It enables startups to create funding projects with customizable goals and terms, while investors can participate using multi-chain assets like ETH, ERC20 tokens, and USDC. The platform ensures transparency through AI-driven risk assessments, automated tokenization (ARCS tokens), and flexible redemption mechanisms.

---
## slide(canva)
https://www.canva.com/design/DAGfjlBYTHA/uH1p2QCTVRvu4nhw-CMN8Q/edit?utm_content=DAGfjlBYTHA&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton

## demo


https://github.com/user-attachments/assets/5e197ecf-f112-490d-ab14-d16165ac1cba



## iamages
![Image](https://github.com/user-attachments/assets/cc6b067d-9a46-43b5-8713-ac4709798df4)

![Image](https://github.com/user-attachments/assets/83428964-010f-4407-b8eb-5ddb12d35985)

![Image](https://github.com/user-attachments/assets/2f1bab60-89c9-4a06-9883-02dac2b03313)

![Image](https://github.com/user-attachments/assets/6c408d3f-2cd5-4526-b314-a352322b30d2)

![Image](https://github.com/user-attachments/assets/05010dbe-5f0e-45f6-bb60-04e897031c19)

![Image](https://github.com/user-attachments/assets/31eb590f-adc6-4639-8cbd-7fcd2aaf41e1)

## Features
1. **Project Management**:  
   - Startups create projects with target amounts, interest rates, and maturity timelines.  
   - Real-time tracking of funding progress and repayment status.

2. **Multi-Chain Investment**:  
   - Accepts ETH, ERC20 tokens, and USDC.  
   - Automated swaps via Uniswap ensure liquidity conversion to USDC.

3. **ARCS Tokenization**:  
   - Mint ERC20-compliant ARCS tokens representing investor stakes.  
   - Burn tokens during redemption/repayment to enforce accountability.

4. **AI-Driven Risk Assessment**:  
   - Evaluates project viability and investor risk profiles (off-chain integration).  

5. **Early Redemption**:  
   - Discounted redemption calculations using time-based formulas.  
   - `EarlyRedemptionLib` for fair value distribution.

6. **Protocol Configuration**:  
   - Customizable fees and redemption rates via `ProtocolConfig`.

7. **Decentralized Provenance**:  
   - OriginTrail integration for immutable audit trails of project terms and transactions.

---

## Technical Architecture

### Core Components
- **Smart Contracts**:  
  - `AssetfyMarket.sol`: Manages project lifecycle, investments, redemptions, and repayments.  
  - `ARCSToken.sol`: Custom ERC20 token with holder tracking via EnumerableSet.  
  - `EarlyRedemptionLib.sol`: Library for calculating discounted redemption values.  

- **Libraries**:  
  - **OpenZeppelin**: ERC20, SafeMath, and access control.  
  - **Uniswap V2**: Swaps ETH/ERC20 tokens to USDC.  

- **Decentralized Storage**:  
  - **OriginTrail**: Stores project metadata and transaction history.  

### Key Functions
- **Project Creation**:  
  ```solidity
  function createProject(string calldata _name, uint256 _targetAmount, ...)


### Completed Milestones
1. **Project Management System**:  
   - Developed a robust smart contract system for creating, managing, and tracking funding projects.  
   - Implemented customizable project parameters (target amount, interest rate, maturity timeline).  

2. **Multi-Chain Investment Support**:  
   - Integrated ETH, ERC20 tokens, and USDC as investment options.  
   - Automated asset swaps via Uniswap for seamless liquidity conversion.  

3. **ARCS Tokenization**:  
   - Created a custom ERC20 token (ARCS) to represent investor stakes.  
   - Implemented token minting and burning mechanisms for accountability.  

4. **Early Redemption Mechanism**:  
   - Developed `EarlyRedemptionLib` for calculating discounted redemption values.  
   - Enabled investors to exit investments before maturity with fair value distribution.  

5. **Protocol Configuration**:  
   - Introduced `ProtocolConfig` for customizable fees and redemption rates.  

6. **Decentralized Provenance Tracking**:  
   - Integrated OriginTrail for immutable audit trails of project terms and transactions.  

7. **Uniswap Integration**:  
   - Enabled automated swaps of ETH and ERC20 tokens to USDC for liquidity.  

8. **Smart Contract Optimization**:  
   - Implemented gas-efficient functions and security measures (e.g., reentrancy guards).  

---

### Upcoming Milestones
1. **AI-Driven Risk Assessment**:  
   - Develop an AI-based system to evaluate project viability and investor risk profiles.  
   - Integrate off-chain AI models for real-time risk analysis.  

2. **Enhanced User Interface**:  
   - Build a user-friendly frontend for startups and investors to interact with the platform.  
   - Integrate PolkadotJS API for seamless frontend-parachain communication.  

3. **Cross-Chain Expansion**:  
   - Explore integration with other blockchain ecosystems (e.g., Polkadot, Cosmos).  

4. **Advanced Analytics Dashboard**:  
   - Provide investors with detailed insights into project performance and ROI.  
---

### Future Vision
- **Decentralized Identity (DID) Integration**:  
  - Enable verified identities for startups and investors to enhance trust.  


- **Partnerships with Traditional Finance**:  
  - Collaborate with traditional financial institutions to bridge DeFi and CeFi.  

---

AssetfyMarket is committed to revolutionizing decentralized fundraising by continuously innovating and expanding its ecosystem. Stay tuned for updates as we work towards achieving these milestones!
















## AssetfyFactory:
https://base-sepolia.blockscout.com/address/0x643fB86AB01FB1e7CCE6caCA5d5B5b2cb0115F

## ARSCMarket:
https://base-sepolia.blockscout.com/address/0xB4486cCa53dFeAa7A688e0ceb68963723Fc7a363?tab=contract


