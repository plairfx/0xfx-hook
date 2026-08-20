// SPDX-License-Identifier: MIT

import {HookVaultBase} from "./HookVaultBase.t.sol";
import {FxHook} from "../../src/0xfxHook.sol";
import {ICurrency} from "../../src/interfaces/ICurrency.sol";

import {console} from "forge-std/console.sol";
pragma solidity ^0.8.22;

contract HookVaultTest is HookVaultBase {
    function test_DepositWorks() public {
        uint256 depositAmount = 10e6;
        usdc.mint(alice, depositAmount);

        // deposit with signature
        uint256 aliceUSDCBalanceBefore = usdc.balanceOf(alice);
        vm.startPrank(alice);

        bytes memory signature = getDepositUSDCSignature(
            Permit({
                owner: alice,
                spender: address(hook),
                value: depositAmount,
                nonce: usdc.nonces(alice),
                deadline: block.timestamp + 10 minutes
            })
        );

        uint256 expectedShares = hook.previewDeposit(depositAmount);

        vm.expectEmit(true, true, true, true);
        emit FxHook.Deposited(alice, address(hook), depositAmount);
        hook.deposit(depositAmount, block.timestamp + 10 minutes, signature);

        // asserts...
        assertEq(expectedShares, hook.balanceOf(alice));
        assertEq(aliceUSDCBalanceBefore - depositAmount, usdc.balanceOf(alice));
        assertEq(hook.totalAssets(), depositAmount);
        assertEq(hook.totalSupply(), expectedShares);
    }

    function test_DepositNotEnoughBalance() public {}

    function test_DepositSharesTurnsIntoAmountFirstTime() public {}

    function test_DepositWrongSignature() public {}

    function test_WithdrawWorks() public {}

    function test_WithdrawRequireBalanceMoreThanAmount() public {}

    function test_WithdrawRequireWithdrawCooldownOver() public {}

    function test_ChangeCoolDownPeriod() public {}

    function test_CooldownPeriodCannotBeCalledByUser() public {}
}
