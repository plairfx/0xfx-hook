// SPDX-License-Identifier: MIT

import {Trade} from "../0xfxTrade.sol";

pragma solidity ^0.8.22;

interface ITrade {
    function getPairInfo(
        address currency0,
        address currency1
    ) external view returns (Trade.PairInfo memory);
}
