// SPDX-License-Identifier: MIT

import {
    SignatureChecker
} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
pragma solidity ^0.8.22;

abstract contract Sign is EIP712 {
    struct TradeRequest {
        address user;
        uint256 oid;
        bool short;
        uint8 orderType;
        uint256 pairID;
        uint256 lotSize;
        uint160 ENTRY_sqrtPriceX96;
        uint160 SL_sqrtPriceX96;
        uint160 TP_sqrtPriceX96;
        uint256 deadline;
        uint256 nonce;
    }

    bytes32 TRADE_HASH =
        keccak256(
            "TradeRequest(address user, uint256 oid, bool short, uint8 orderType, uint256 pairID, uint256 lotSize, uint160 ENTRY_sqrtPriceX96, uint160 SL_sqrtPriceX96, uint160 TP_sqrtPriceX96, uint256 deadline, uint256 nonce)"
        );

    constructor() EIP712("0xfx", "1.0.0") {}

    function getSigner(
        bytes memory signature,
        bytes32 hash,
        address owner
    ) public view returns (bool) {
        return SignatureChecker.isValidSignatureNow(owner, hash, signature);
    }

    function getTradeHash(
        TradeRequest memory _message
    ) public view returns (bytes32) {
        return (
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        TRADE_HASH,
                        keccak256(bytes(abi.encode(_message)))
                    )
                )
            )
        );
    }
}
