// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library EarlyRedemptionLib {
    uint256 constant YEAR_SECONDS = 365 days;
    
    /**
     * @dev Calculates the discounted redemption amount.
     * @param maturityTime The timestamp at which the bond matures.
     * @param annualInterestRate The simple annual interest rate in % (e.g., 10 means 10%).
     * @param arfcAmount The quantity of ARFC tokens being redeemed (18 decimals).
     * @param currentTime The current block timestamp.
     * @return discountedValue The discounted USDC amount owed to the redeemer.
     */
    function calculateDiscountedValue(
        uint256 maturityTime,
        uint256 annualInterestRate,
        uint256 arfcAmount,
        uint256 currentTime
    ) external pure returns (uint256 discountedValue) 
    {
        // timeRemaining = maturityTime - currentTime
        // fractionOfYear = (timeRemaining / YEAR_SECONDS)
        // interestRate e.g. 10 => 10% => 0.10 in decimal
        // faceValuePerToken = 1 + (r * fractionOfYear)
        // discountFactor = 1 / (1 + r * fractionOfYear)
        // discountedValuePerToken = faceValuePerToken * discountFactor

        if (currentTime >= maturityTime) {
            // If for some reason this is called after maturity, just return 0 
            // (the main contract should revert anyway).
            return 0;
        }

        uint256 timeRemaining = maturityTime - currentTime;
        // Convert interest rate (e.g., 10 => 10% => 0.10 in 1e18 scale => 10 * 1e16 = 1e17)
        uint256 r = annualInterestRate * 1e16; 

        // fractionOfYear in 1e18 scale
        uint256 fractionOfYear = (timeRemaining * 1e18) / YEAR_SECONDS;

        // faceValuePerToken in 1e18 scale: 1e18 means "1 USDC" in 1e18
        // faceValuePerToken = 1e18 + (r * fractionOfYear / 1e18)
        uint256 faceValuePerToken = 1e18 + (r * fractionOfYear / 1e18);

        // discountFactor = 1e18 / faceValuePerToken
        // However, the example used: discountFactor = 1 / (1 + r*(timeRemaining/YEAR))
        // We'll approximate it with faceValue again for demonstration.
        // A naive formula:
        // discountFactor = 1e18 / (1e18 + (r*fractionOfYear/1e18))
        uint256 discountFactor = (1e18 * 1e18) / faceValuePerToken;

        // discountedValuePerToken = faceValuePerToken * discountFactor / 1e18
        uint256 discountedValuePerToken = (faceValuePerToken * discountFactor) / 1e18;

        // Multiply by number of tokens
        discountedValue = (arfcAmount * discountedValuePerToken) / 1e18;
    }
}
