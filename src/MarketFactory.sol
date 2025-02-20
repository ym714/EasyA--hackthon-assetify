// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ARCSMarket.sol";

contract AssetfyMarketFactory {
    address public curator;

    address[] public allMarkets;

    event MarketCreated(address indexed newMarket, address indexed curator);

    constructor() {
        curator = msg.sender;
    }

    modifier onlyCurator() {
        require(msg.sender == curator, "Not curator");
        _;
    }

    function createAssetfyMarket(
        address owner,
        address _usdc,
        address _uniswapRouter,
        AssetfyMarket.ProtocolConfig memory _config
    ) external onlyCurator returns (address) {
        AssetfyMarket newMarket = new AssetfyMarket(_usdc,owner, _uniswapRouter, _config);

        allMarkets.push(address(newMarket));
        emit MarketCreated(address(newMarket), curator);

        return address(newMarket);
    }

    function getAllMarkets() external view returns (address[] memory) {
        return allMarkets;
    }
}
