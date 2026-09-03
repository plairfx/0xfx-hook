// SDPX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {IPyth, PythStructs} from "./interfaces/Pyth/IPyth.sol";

contract Oracle {
    IPyth pyth;

    constructor(address _pyth) {
        pyth = IPyth(_pyth);
    }

    /// @notice gets currentPrice from the pythOracle
    function getCurrentPrice(
        bytes32 feedID,
        uint256 validTimeDistance
    ) external returns (PythStructs.Price memory) {
        return pyth.getPriceNoOlderThan(feedID, validTimeDistance);
    }
}
