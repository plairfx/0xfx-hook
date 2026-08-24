// SPDX-License-Identifier: MIT

import {
    HookVaultBase,
    PoolId,
    PoolSwapTest,
    TickMath,
    SwapParams,
    ModifyLiquidityParams,
    PoolId,
    StateLibrary,
    IPoolManager
} from "./HookVaultBase.t.sol";
import {FxHook} from "../../src/0xfxHook.sol";
import {ICurrency} from "../../src/interfaces/ICurrency.sol";

import {console} from "forge-std/console.sol";

pragma solidity ^0.8.22;

contract HookVaultTest is HookVaultBase {
    using StateLibrary for IPoolManager;
    function test_SwapWorks() public {
        PoolId poolId = key.toId();

        (uint160 sqrtPriceX962, int24 tick2, , ) = manager.getSlot0(poolId);

        uint256 EurBalanceBefore = EUR.balanceOf(owner);
        uint256 USDBalanceBefore = USD.balanceOf(owner);

        vm.startPrank(owner);
        PoolSwapTest.TestSettings memory TestSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -1e6, // we want to swap 10 EUR > 11.16590 USD!
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        swapRouter.swap(key, params, TestSettings, ZERO_BYTES);

        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        ) = manager.getSlot0(poolId);

        // asserts
        assertGt(EurBalanceBefore, EUR.balanceOf(owner));
        assertGt(USD.balanceOf(owner), USDBalanceBefore);
    }

    //Before swap implemenation:
    // first we need to work on the Trade contract, but first
    // lets make sure we are restricting other pools from interacting with this.

    function test_SwapExecutesLimitOrders() public {}

    function test_SwapExecutesTakeProfits() public {}

    function test_SwapExecutesStoplosses() public {}

    function test_SwapExecutesLiquidations() public {}
}
