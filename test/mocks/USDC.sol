// SPDX-License-Identifier: MIT

import {
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

pragma solidity 0.8.34;

contract USDC is ERC20, ERC20Permit {
    constructor() ERC20Permit("USDC") ERC20("USDC", "USDC") {}

    function decimals() public view override returns (uint8) {
        return 6;
    }

    function mint(address user, uint256 amount) public {
        _mint(user, amount);
    }
}
