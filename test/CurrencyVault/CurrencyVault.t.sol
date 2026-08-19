// SPDX-License-Identifier: MIT

import {CurrencyVaultBase} from "./CurrencyVaultBase.t.sol";
import {CurrencyVault} from "../../src/0xfxCurrencyVault.sol";

pragma solidity 0.8.34;

contract CurrencyVaultTest is CurrencyVaultBase {
    // Init Functions..
    function test_NonVaultOwnerCannotInitialize() public {
        vm.startPrank(alice);

        CurrencyVault.CurrencyInfo memory C = CurrencyVault.CurrencyInfo({
            currencyID: 1,
            currencyName: "EURO",
            currencyCode: "EUR",
            currencyAddr: address(0x0),
            pythFeedID: EURUSD_PRICE_FEED_ID,
            currentPrice: 0,
            lastUpdated: 0,
            active: false
        });
        vm.expectRevert("NotTheOwner()");

        cv.initCurrency(C);
    }

    function test_InitializedCurrencyCannotBeIntializedAgain() public {
        initializePyth();
        initializedCurrency();

        vm.startPrank(owner);
        CurrencyVault.CurrencyInfo memory C = CurrencyVault.CurrencyInfo({
            currencyID: 1,
            currencyName: "EURO",
            currencyCode: "EUR",
            currencyAddr: address(0x0),
            pythFeedID: EURUSD_PRICE_FEED_ID,
            currentPrice: 0,
            lastUpdated: 0,
            active: false
        });
        vm.expectRevert("CurrencyAlreadyActive()"); // not predicting the addr..
        cv.initCurrency(C);
    }
}
