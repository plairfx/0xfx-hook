// SPDX-License-Identifier: MIT

import {HookVaultBase} from "./HookVaultBase.t.sol";
import {FxHook} from "../../src/0xfxHook.sol";
import {ICurrency} from "../../src/interfaces/ICurrency.sol";

import {console} from "forge-std/console.sol";
pragma solidity ^0.8.22;

contract HookVaultTest is HookVaultBase {
    uint256 depositAmount = 10e6;

    function test_AssertsInitialValues() public {
        assertEq(hook.decimals(), 6);
        assertEq(hook.asset(), address(usdc));
    }

    function test_Setup() public {}

    function test_DepositWorks() public {
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
        uint256 expectedShares2 = hook.previewMint(depositAmount);

        vm.expectEmit(true, true, true, true);
        emit FxHook.Deposited(alice, address(alice), depositAmount);
        hook.deposit(depositAmount, block.timestamp + 10 minutes, signature);

        // asserts...
        assertEq(expectedShares, hook.balanceOf(alice));
        assertEq(aliceUSDCBalanceBefore - depositAmount, usdc.balanceOf(alice));
        assertEq(hook.totalAssets(), depositAmount);
        assertEq(hook.totalSupply(), expectedShares);
        assertEq(hook.totalSupply(), depositAmount);

        // check this
        assertEq(expectedShares, expectedShares2);
    }

    function test_DepositNotEnoughBalance() public {
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

        vm.expectRevert("Not Enough Balance");
        hook.deposit(depositAmount, block.timestamp + 10 minutes, signature);
    }

    function test_DepositWrongSignature() public {
        aliceMintedUSDC();
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

        vm.expectRevert();
        hook.deposit(depositAmount, block.timestamp + 11 minutes, signature);
    }

    function test_WithdrawWorks() public {
        aliceDeposited10USDC();
        // lets withdraw 90%.
        uint256 totalSupplyBefore = hook.totalSupply();
        uint256 totalAssetsBefore = hook.totalSupply();

        uint256 aliceShareBalanceBefore = hook.balanceOf(alice);

        uint256 sharesToWithdraw = (hook.balanceOf(alice) * 10) / 100;
        uint256 usdcBalanceBefore = usdc.balanceOf(alice);
        uint256 redemptionAmount = hook.previewRedeem(sharesToWithdraw);
        vm.warp(block.timestamp + 3 days);
        vm.expectEmit(true, true, true, true);
        emit FxHook.Withdrawn(alice, alice, redemptionAmount);

        hook.withdraw(sharesToWithdraw, alice);

        // assertBalances..
        assertEq(
            aliceShareBalanceBefore - sharesToWithdraw,
            hook.balanceOf(alice)
        );
        assertEq(usdcBalanceBefore + redemptionAmount, usdc.balanceOf(alice));
        assertEq(
            aliceShareBalanceBefore - sharesToWithdraw,
            hook.balanceOf(alice)
        );
        assertEq(totalSupplyBefore - sharesToWithdraw, hook.totalSupply());
        assertEq(totalAssetsBefore - redemptionAmount, hook.totalAssets());
    }

    function test_WithdrawRequireBalanceMoreThanAmount() public {
        // lets withdraw 90%.
        uint256 sharesToWithdraw = (hook.balanceOf(alice) * 10) / 100;
        vm.expectRevert("Not Enough Balance");
        hook.withdraw(sharesToWithdraw, alice);

        aliceDeposited10USDC();
        // amoiunt cannot be zero
        vm.expectRevert("Not Enough Balance");
        hook.withdraw(0, alice);
    }

    function test_WithdrawRequireWithdrawCooldownOver() public {
        aliceDeposited10USDC();
        uint256 sharesToWithdraw = (hook.balanceOf(alice) * 10) / 100;
        uint256 redemptionAmount = hook.previewRedeem(sharesToWithdraw);
        vm.expectRevert("Cannot Withdraw Yet");
        hook.withdraw(sharesToWithdraw, alice);

        vm.warp(block.timestamp + 3 days);

        vm.expectEmit(true, true, true, true);
        emit FxHook.Withdrawn(alice, alice, redemptionAmount);
        hook.withdraw(sharesToWithdraw, alice);
    }

    function test_ChangeCoolDownPeriod() public {
        // current is 3 days.
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit FxHook.CooldownPeriodChanged(3 days, 30 days);
        hook.changeCooldownPeriod(30 days);
    }

    function test_CooldownPeriodCannotBeCalledByUser() public {
        vm.startPrank(alice);
        vm.expectRevert("Not the owner");
        hook.changeCooldownPeriod(4 days);
    }

    function test_CannotChangeCooldownMoreThanMax() public {
        vm.expectRevert("Cannot be more than MAX_CD");
        vm.startPrank(owner);
        hook.changeCooldownPeriod(30 days + 1 seconds);
    }

    //
}
