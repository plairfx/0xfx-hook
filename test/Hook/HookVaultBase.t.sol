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

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    address owner = makeAddr("owner");
    uint256 alicePK;
    address alice;

    function setUp() external {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        usdc = new USDC();

        // testie..
        address hookAddress = address(
            uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG)
        );

        deployCodeTo(
            "src/0xfxHook.sol",
            abi.encode(manager, address(usdc)),
            hookAddress
        );

        hook = FxHook(hookAddress);
        (alice, alicePK) = makeAddrAndKey("alice");
        // We dont need ot set it up fully atm, but no
    }

    function aliceMintedUSDC() public {
        usdc.mint(alice, 100e6);
    }

    function aliceDeposited10USDC() public {
        aliceMintedUSDC();

        // depositing..
        vm.startPrank(alice);
        uint256 depositAmount = 10e6;
        bytes memory signature = getDepositUSDCSignature(
            Permit({
                owner: alice,
                spender: address(hook),
                value: depositAmount,
                nonce: usdc.nonces(alice),
                deadline: block.timestamp + 10 minutes
            })
        );

        hook.deposit(depositAmount, block.timestamp + 10 minutes, signature);
    }

    function getDepositUSDCSignature(
        Permit memory P
    ) public view returns (bytes memory) {
        bytes32 GH = getUSDCMessage(P);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePK, GH);

        return abi.encodePacked(r, s, v);
    }

    function getUSDCMessage(Permit memory P) public view returns (bytes32) {
        return (
            keccak256(
                abi.encodePacked(
                    hex"1901",
                    usdc.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            P.owner,
                            P.spender,
                            P.value,
                            usdc.nonces(P.owner),
                            P.deadline
                        )
                    )
                )
            )
        );
    }
}
