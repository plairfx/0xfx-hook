// SPDX-License-Identifier: MIT

import {Lib} from "../utils/0xLib.sol";
pragma solidity ^0.8.22;

interface ICurrencyVault {
    function getCurrencyInfo(
        uint256 cid
    ) external view returns (Lib.CurrencyInfo memory);

    function getCurrencyIDInfo(address cidAddr) external view returns (uint256);
}
