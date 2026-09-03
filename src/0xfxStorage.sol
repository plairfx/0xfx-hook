// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {Heap} from "@openzeppelin/contracts/utils/structs/Heap.sol";

/// @title Storage Contract
/// @author The name of the author
/// @notice This contract stores all the pending orders to be executed
/// @dev This contract uses a Heap to store all the pending order and to get them
// Whenever a orderID is retrieved it will be removed from the heap.

contract Storage {
    address trade;

    mapping(uint256 pairID => mapping(int24 tick => mapping(int24 tickRange => Heap.Uint256Heap))) priceInfo;

    modifier onlyTrade() {
        require(isTrade(msg.sender), "Not the trade addr");
        _;
    }

    constructor(address _trade) {
        trade = _trade;
    }

    /// @notice inserts the orderID with the pairID & tick and tickRange into the mapping Heap.
    function insertOrder(
        uint256 pairID,
        int24 tick,
        int24 tickRange,
        uint256 orderID
    ) external onlyTrade {
        Heap.Uint256Heap storage H = priceInfo[pairID][tick][tickRange];
        Heap.insert(H, orderID);
    }
    /// @notice removes the first inserted order (lowes tnumber) from the heap.
    function popFirstOrder(
        uint256 pairID,
        int24 tick,
        int24 tickRange
    ) external onlyTrade returns (uint256) {
        Heap.Uint256Heap storage H = priceInfo[pairID][tick][tickRange];

        return Heap.pop(H);
    }
    /// @notice peeks the first inserted order (lowes tnumber) from the heap.
    function getFirstOrderOut(
        uint256 pairID,
        int24 tick,
        int24 tickRange
    ) external returns (uint256) {
        Heap.Uint256Heap storage H = priceInfo[pairID][tick][tickRange];

        return Heap.peek(H);
    }

    function isTrade(address _trade) internal view returns (bool) {
        return _trade == trade;
    }
}
