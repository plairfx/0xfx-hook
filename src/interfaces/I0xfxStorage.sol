// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

interface IStorage {
    function getFirstOrderOut(
        uint256 pairID,
        int24 tick,
        int24 tickRange
    ) external returns (uint256);

    function popFirstOrder(
        uint256 pairID,
        int24 tick,
        int24 tickrange
    ) external returns (uint256);

    function insertOrder(
        uint256 pairID,
        int24 tick,
        int24 tickRange,
        uint256 orderID
    ) external;
}
