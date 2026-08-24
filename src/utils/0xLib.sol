// SPDX-License-Identifier: MIT

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

pragma solidity ^0.8.22;

library Lib {
    struct CurrencyInfo {
        uint256 currencyID;
        string currencyName;
        string currencyCode;
        address currencyAddr;
        bytes32 pythFeedID;
        uint256 currentPrice;
        uint256 lastUpdated;
        bool active;
    }

    struct PairInfo {
        uint256 baseCurrencyID;
        uint256 quoteCurrencyID;
        string PairName;
        uint256 lastPrice;
        bytes32 pythFeed;
        uint256 updatedAt;
        bool active;
    }
    function getParsedSignature(
        bytes memory signature
    ) internal view returns (uint8, bytes32, bytes32) {
        return ECDSA.parse(signature);
    }
}
