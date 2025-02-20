// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ARCSToken is ERC20 {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _holders;
    uint256 public maturityTime;
    address public protocol;

    modifier onlyProtocol() {
        require(msg.sender == protocol, "Only protocol can call");
        _;
    }

    constructor(string memory name_, string memory symbol_, address _protocol, uint256 _maturityTime) ERC20(name_, symbol_) {
        protocol = _protocol;
        maturityTime = _maturityTime;
    }

    function mint(address to, uint256 amount) external onlyProtocol {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyProtocol {
        _burn(from, amount);
    }

    function _update(address from, address to, uint256 amount) internal virtual override {
        super._update(from, to, amount);

        if (to != address(0) && balanceOf(to) > 0) {
            _holders.add(to);
        }
        if (from != address(0) && balanceOf(from) == 0) {
            _holders.remove(from);
        }
    }

    function getHolders() external view returns (address[] memory) {
        return _holders.values();
    }

    function isHolder(address account) external view returns (bool) {
        return _holders.contains(account);
    }
}