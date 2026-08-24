// SDPX-License-Identifier: MIT

import {IPyth, PythStructs} from "./interfaces/Pyth/IPyth.sol";

pragma solidity ^0.8.22;

contract Oracle {
    IPyth pyth;

    constructor(address _pyth) {
        pyth = IPyth(_pyth);
    }

    function getCurrentPrice(
        bytes32 feedID,
        uint256 validTimeDistance
    ) external returns (PythStructs.Price memory) {
        return pyth.getPriceNoOlderThan(feedID, validTimeDistance);
    }
}
