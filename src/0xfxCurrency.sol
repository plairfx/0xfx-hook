// SDPX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {
    ERC20Permit,
    ERC20
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract CurrencyFX is ERC20Permit {
    address immutable CURRENCY_VAULT;

    modifier onlyVaultCheck() {
        require(onlyVault(), "Not the Vault");
        _;
    }

    /// @dev base contract for a currency in the 0xfx protocol
    /// @param currencyName e.g EUR
    /// @param currencyCode e.g EURO -> EUR.
    constructor(
        string memory currencyName,
        string memory currencyCode,
        address currencyVault
    ) ERC20Permit("currencyName") ERC20(currencyName, currencyCode) {
        CURRENCY_VAULT = currencyVault;
    }

    /// @notice only allows currencyVault to mint tokens
    function mint(uint256 amount, address receiver) external onlyVaultCheck {
        _mint(receiver, amount);
    }
    /// @notice only allows currencyVault to burn tokens
    function burn(uint256 amount, address user) external onlyVaultCheck {
        _burn(user, amount);
    }

    function onlyVault() internal view returns (bool) {
        return msg.sender == CURRENCY_VAULT;
    }
}
