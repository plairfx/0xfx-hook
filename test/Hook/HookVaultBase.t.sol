// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Test} from "forge-std/Test.sol";
import {USDC} from "../mocks/USDC.sol";
import {FxHook} from "../../src/0xfxHook.sol";

// Uniswap related;
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {
    SwapParams,
    ModifyLiquidityParams
} from "v4-core/types/PoolOperation.sol";
import {SwapMath} from "@uniswap/v4-core/src/libraries/SwapMath.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

contract HookVaultBase is Test, Deployers {
    FxHook hook;
    USDC usdc;

    function setUp() external {
        deployFreshManagerAndRouters();

        // testie..
        address hookAddress = address(uint160(Hooks.BEFORE_SWAP_FLAG));

        deployCodeTo("0xfxHook.sol", abi.encode(manager), hookAddress);

        hook = FxHook(hookAddress, IERC20(usdc));

        // We dont need ot set it up fully atm, but no
    }
}
