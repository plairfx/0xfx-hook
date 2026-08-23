// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

contract Trade {
    struct PairInfo {
        bool active;
    }

    mapping(address => mapping(address => PairInfo)) pairInfo;

    function getPairInfo(
        address currency0,
        address currency1
    ) public view returns (PairInfo memory) {
        return pairInfo[currency0][currency1];
    }
}
