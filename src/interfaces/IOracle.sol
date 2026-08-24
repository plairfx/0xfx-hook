// SPDX-License-Identifier: MIT

import {IPyth, PythStructs} from "./Pyth/IPyth.sol";

pragma solidity ^0.8.22;
pragma solidity ^0.8.22;

interface IOracle {
    function getCurrentPrice(
        bytes32 feedID,
        uint256 validTimeDistance
    ) external view returns (PythStructs.Price memory);
}
