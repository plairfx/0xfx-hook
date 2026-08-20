// SDPX-License-Identifier: MIT

import {
    ERC20Permit,
    ERC20
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

pragma solidity ^0.8.22;
contract Currency is ERC20Permit {
    address immutable CURRENCY_VAULT;

    modifier onlyVaultCheck() {
        require(onlyVault(), "Not the Vault");
        _;
    }
    constructor(
        string memory currencyName,
        string memory currencyCode,
        address currencyVault
    ) ERC20Permit("currencyName") ERC20(currencyName, currencyCode) {
        CURRENCY_VAULT = currencyVault;
    }

    function mint(uint256 amount, address receiver) external onlyVaultCheck {
        _mint(receiver, amount);
    }

    function burn(uint256 amount, address user) external onlyVaultCheck {
        _burn(user, amount);
    }

    function onlyVault() internal view returns (bool) {
        return msg.sender == CURRENCY_VAULT;
    }
}
