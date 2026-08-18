// SDPX-License-Identifier: MIT

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity 0.8.34;

contract Currency is ERC20 {
    error NotTheVault();
    address immutable CURRENCY_VAULT;

    modifier onlyVaultCheck() {
        require(onlyVault(), NotTheVault());
        _;
    }
    constructor(
        string memory currencyName,
        string memory currencyCode
    ) ERC20(currencyName, currencyCode) {}

    function mint(uint256 amount, uint256 receiver) external onlyVaultCheck {
        _mint(receiver, amount);
    }

    function onlyVault() internal view returns (bool) {
        return msg.sender == CURRENCY_VAULT;
    }
}
