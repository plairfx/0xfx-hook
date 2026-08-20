// SPDX-License-Identifier: MIT

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

pragma solidity 0.8.34;

library Lib {
    // eip712 is thehash messaging,
    // @important, use the signature checking mock and test it.

    error NotEnoughBalance();

    function getParsedSignature(
        bytes memory signature
    ) internal view returns (uint8, bytes32, bytes32) {
        return ECDSA.parse(signature);
    }
}
