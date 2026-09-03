// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {Heap} from "@openzeppelin/contracts/utils/structs/Heap.sol";

contract Storage {
    mapping(uint256 pairID => mapping(int24 tick => mapping(int24 tickRange => Heap.Uint256Heap))) priceInfo;

    address trade;
    event Testie(uint256);
    modifier onlyTrade() {
        require(isTrade(msg.sender), "Not the trade addr");
        _;
    }

    constructor(address _trade) {
        trade = _trade;
    }

    function insertOrder(
        uint256 pairID,
        int24 tick,
        int24 tickRange,
        uint256 orderID
    ) external onlyTrade {
        Heap.Uint256Heap storage H = priceInfo[pairID][tick][tickRange];
        emit Testie(Heap.length(H));
        Heap.insert(H, orderID);
        emit Testie(Heap.length(H));
    }

    function popFirstOrder(
        uint256 pairID,
        int24 tick,
        int24 tickRange
    ) external onlyTrade returns (uint256) {
        Heap.Uint256Heap storage H = priceInfo[pairID][tick][tickRange];

        return Heap.pop(H);
    }

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
