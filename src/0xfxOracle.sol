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
    ) external returns (int256) {
        PythStructs.Price memory price;

        try pyth.getPriceNoOlderThan(feedID, validTimeDistance) {
            price = pyth.getPriceNoOlderThan(feedID, validTimeDistance);
        } catch {
            // reverts if updatedTime - block.timestamp is less than  - age we set.
            revert();
        }
        return price.price;
    }
}
