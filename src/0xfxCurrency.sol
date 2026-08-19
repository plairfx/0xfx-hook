// SDPX-License-Identifier: MIT

import {
    ERC20Permit,
    ERC20
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

pragma solidity 0.8.34;

contract Currency is ERC20Permit {
    error NotTheVault();
    address immutable CURRENCY_VAULT;

    modifier onlyVaultCheck() {
        require(onlyVault(), NotTheVault());
        _;
    }
    constructor(
        string memory currencyName,
        string memory currencyCode
    ) ERC20Permit("currencyName") ERC20(currencyName, currencyCode) {}

    function mint(uint256 amount, address receiver) external onlyVaultCheck {
        _mint(receiver, amount);
    }

    function onlyVault() internal view returns (bool) {
        return msg.sender == CURRENCY_VAULT;
    }
}
