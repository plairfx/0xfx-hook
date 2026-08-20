// SPDX-License-Identifier: MIT

import {CurrencyVaultBase} from "./CurrencyVaultBase.t.sol";
import {CurrencyVault} from "../../src/0xfxCurrencyVault.sol";
import {ICurrency} from "../../src/interfaces/ICurrency.sol";
import {IPyth, PythStructs} from "../../src/interfaces/Pyth/IPyth.sol";

import {console} from "forge-std/console.sol";
pragma solidity ^0.8.22;

contract CurrencyVaultTest is CurrencyVaultBase {
    address currencyAddr = 0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2;
    bytes empty_signature;
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
        vm.expectRevert("Not the owner");

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
        vm.expectRevert("Currency Already Active!");
        cv.initCurrency(C);
    }

    function test_InitializeCurrencyWithStalePriceReverts() public {
        initializePyth();

        // warp more than 60 seconds
        vm.warp(2 minutes);
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

        // stalePrice revert.
        vm.expectRevert();
        cv.initCurrency(C);
    }

    // Deposit..

    function test_Deposit() public {
        initializePyth();
        initializedCurrency();
        mintAliceUSDC();

        uint256 usdcBalanceAlice = usdc.balanceOf(alice);
        uint256 EURBalanceAlice = ICurrency(currencyAddr).balanceOf(alice);
        vm.startPrank(alice);

        uint256 deadline = block.timestamp + 10 minutes;
        uint256 amount = 10e6;
        bytes memory signature = getDepositUSDCSignature(
            Permit({
                owner: alice,
                spender: address(cv),
                value: amount,
                nonce: usdc.nonces(alice),
                deadline: deadline
            })
        );

        cv.deposit(1, amount, signature, deadline);

        uint256 usdcBalanceAliceAfter = usdc.balanceOf(alice);
        uint256 EURBalanceAliceAfter = ICurrency(currencyAddr).balanceOf(alice);

        assertEq(usdcBalanceAlice - amount, usdcBalanceAliceAfter);
        assertEq(
            EURBalanceAlice + (amount / (116595 + 10)),
            EURBalanceAliceAfter
        );
    }

    function test_DepositRequiresActiveCurrency() public {
        vm.startPrank(alice);
        vm.expectRevert("Currency Not Active");

        cv.deposit(1, 100e6, empty_signature, 0);
    }

    function test_DepositRequiresAmountMoreThanZero() public {
        initializePyth();
        initializedCurrency();
        mintAliceUSDC();

        vm.startPrank(alice);
        vm.expectRevert("Cant be Zero");
        cv.deposit(1, 0, empty_signature, 0);
    }

    function test_DepositRequiresValidSignature() public {
        initializePyth();
        initializedCurrency();
        mintAliceUSDC();

        vm.startPrank(alice);

        uint256 deadline = block.timestamp + 10 minutes;
        uint256 amount = 10e6;
        bytes memory signature = getDepositUSDCSignature(
            Permit({
                owner: alice,
                spender: address(cv),
                value: amount,
                nonce: usdc.nonces(alice),
                deadline: deadline
            })
        );

        vm.expectRevert();
        cv.deposit(1, amount, signature, deadline + 1 minutes); // adding + 1 minute than signed deadline.
    }

    function test_DepositRequiresNonStalePrice() public {
        initializePyth();
        initializedCurrency();
        mintAliceUSDC();

        uint256 amount = 10e6; // 10 USDC
        vm.warp(block.timestamp + 61 seconds);

        vm.startPrank(alice);
        usdc.approve(address(cv), amount);

        vm.expectRevert();
        cv.deposit(1, amount, empty_signature, 0);
    }

    // Withdraw...

    function test_Withdraw() public {
        aliceDeposited10USDCForEUR();

        PythStructs.Price memory PP = pyth.getPriceNoOlderThan(
            EURUSD_PRICE_FEED_ID,
            60
        );

        uint256 usdcBalanceAlice = usdc.balanceOf(alice);
        uint256 EURBalanceAlice = ICurrency(currencyAddr).balanceOf(alice);
        uint256 amount = EURBalanceAlice; // i want to withdraw the whole balance!.

        uint256 expectedUSDCAmount = amount * uint256(int256(PP.price));
        vm.startPrank(alice);
        vm.expectEmit(true, true, true, true);
        emit CurrencyVault.Withdrawn(alice, expectedUSDCAmount, currencyAddr);

        cv.withdraw(1, amount);

        uint256 usdcBalanceAliceAfter = usdc.balanceOf(alice);
        uint256 EURBalanceAliceAfter = ICurrency(currencyAddr).balanceOf(alice);

        // the maths dont add up here.
        assertEq(usdcBalanceAlice + expectedUSDCAmount, usdcBalanceAliceAfter);
        assertEq(EURBalanceAlice - EURBalanceAlice, EURBalanceAliceAfter);
    }

    function test_WithdrawRequiresActiveCurrency() public {
        vm.startPrank(alice);

        vm.expectRevert("Currency Not Active");
        cv.withdraw(1, 10e6);
    }

    function test_WithdrawRequiresAmountMoreThanZero() public {
        initializePyth();
        initializedCurrency();
        mintAliceUSDC();
        vm.expectRevert("Not Enough Balance");
        cv.withdraw(1, 0);
    }

    function test_WithdrawRequiresEnoughCurrencyBalance() public {
        initializePyth();
        initializedCurrency();

        vm.startPrank(alice);
        uint256 aliceBalance = ICurrency(currencyAddr).balanceOf(alice);
        vm.expectRevert("Not Enough Balance");
        cv.withdraw(1, aliceBalance);
    }

    function test_WithdrawRequiresNonStalePrice() public {
        aliceDeposited10USDCForEUR();
        vm.warp(block.timestamp + 61 seconds);
        vm.startPrank(alice);
        uint256 aliceBalance = ICurrency(currencyAddr).balanceOf(alice);
        vm.expectRevert();
        cv.withdraw(1, aliceBalance);
    }

    // Currency Tests.

    function test_OnlyVaultOwnerCanMint() public {
        // Initialized Pyth Oracle and currencies..

        initializePyth();
        initializedCurrency();
        vm.startPrank(alice);
        vm.expectRevert("Not the Vault");
        ICurrency(currencyAddr).mint(10e6, alice);
    }

    function test_OnlyVaultOwnerCanBurn() public {
        // Initialized Pyth Oracle and currencies..

        initializePyth();
        initializedCurrency();
        vm.startPrank(alice);
        vm.expectRevert("Not the Vault");
        ICurrency(currencyAddr).burn(10e6, alice);
    }
}
