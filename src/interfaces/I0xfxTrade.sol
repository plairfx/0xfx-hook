// SPDX-License-Identifier: MIT

import {Trade} from "../0xfxTrade.sol";
import {Lib} from "../utils/0xLib.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

pragma solidity ^0.8.22;

interface ITrade {
    function getPairInfo(
        address currency0,
        address currency1
    ) external view returns (Trade.PairInfo memory);

    function afterTrade(
        int24 tick,
        uint160 sqrtPricex96,
        PoolKey calldata key
    ) external;

    function initPairKeyID(
        address baseCurrency,
        address quoteCurrency,
        PoolKey calldata key
    ) external;
}
