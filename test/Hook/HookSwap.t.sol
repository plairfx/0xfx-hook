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
import {Trade} from "../../src/0xfxTrade.sol";
import {console} from "forge-std/console.sol";
import {Sign} from "../../src/utils/0xSignature.sol";
import {SwapMath} from "@uniswap/v4-core/src/libraries/SwapMath.sol";

pragma solidity ^0.8.22;

contract HookVaultTest is HookVaultBase {
    using StateLibrary for IPoolManager;
    function test_SwapWorks() public {
        PoolId poolId = key.toId();

        (uint160 sqrtPriceX962, int24 tick2, , ) = manager.getSlot0(poolId);
        console.log("tickPrice Before", sqrtPriceX962);
        uint256 EurBalanceBefore = EUR.balanceOf(owner);
        uint256 USDBalanceBefore = USD.balanceOf(owner);

        vm.startPrank(owner);
        PoolSwapTest.TestSettings memory TestSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -50e14, // we want to swap 10 EUR > 11.16590 USD!
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        swapRouter.swap(key, params, TestSettings, ZERO_BYTES);

        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        ) = manager.getSlot0(poolId);
        console.log("tickPrice After", tick);

        console.log(
            "Convert TickRange",
            TickMath.getTickAtSqrtPrice(TickMath.getSqrtPriceAtTick(1533)) // 1834
        );
        // asserts
        assertGt(EurBalanceBefore, EUR.balanceOf(owner));
        assertGt(USD.balanceOf(owner), USDBalanceBefore);
    }

    function test_SwapExecutesLimitOrders() public {
        vm.startPrank(address(cv));
        USD.mint(100e6, alice);
        EUR.mint(100e6, address(hook));
        bytes memory signature;
        vm.startPrank(alice);
        Trade.PairInfo memory PI = trade.getPairInfo(
            address(EUR),
            address(USD)
        );
        PoolId id = PI.pk.toId();
        (uint160 currentSqrtPricex96, , , ) = manager.getSlot0(id);
        /// we will swapComputeStep a bgi swap and swap it !

        // get the next swap hmm..
        (uint160 sqrtPriceNextX96, , , ) = SwapMath.computeSwapStep({
            sqrtPriceCurrentX96: currentSqrtPricex96,
            sqrtPriceTargetX96: 4295128739 + 1,
            liquidity: manager.getLiquidity(id),
            amountRemaining: -50e14,
            feePips: 0
        });
        Sign.TradeRequest memory TR = Sign.TradeRequest({
            user: alice,
            oid: 0,
            short: false,
            orderType: 1,
            pairID: 1,
            lotSize: 1e6,
            ENTRY_sqrtPriceX96: sqrtPriceNextX96,
            TP_sqrtPriceX96: 0,
            SL_sqrtPriceX96: 0,
            deadline: 0,
            nonce: 0
        });
        trade.trade(TR, signature);

        console.log("Next Price", sqrtPriceNextX96);
        // deposit usdc...

        USD.approve(address(trade), 10e6);

        vm.expectEmit(true, true, true, true);
        emit Trade.Deposited(alice, alice, 10e6);
        trade.depositUSD(alice, 10e6, 0, signature);

        // Place Limit order..

        console.log("ddress trade", address(trade));
        console.log("address HOOK", address(hook));

        vm.startPrank(owner);
        PoolSwapTest.TestSettings memory TestSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});

        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: -50e14,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        swapRouter.swap(key, params, TestSettings, ZERO_BYTES);
    }

    function test_SwapExecutesTakeProfits() public {}

    function test_SwapExecutesStoplosses() public {}

    function test_SwapExecutesLiquidations() public {}
}
