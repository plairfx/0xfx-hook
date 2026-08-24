// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {Test, console} from "forge-std/Test.sol";
import {USDC} from "../mocks/USDC.sol";
import {FxHook} from "../../src/0xfxHook.sol";
import {CurrencyFX} from "../../src/0xfxCurrency.sol";
import {MockPyth} from "../mocks/MockPyth.sol";
import {CurrencyVault} from "../../src/0xfxCurrencyVault.sol";
import {ICurrency} from "../../src/interfaces/ICurrency.sol";
import {Trade} from "../../src/0xfxTrade.sol";
import {Oracle} from "../../src/0xfxOracle.sol";

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
    using StateLibrary for IPoolManager;
    FxHook hook;
    USDC usdc;
    ICurrency EUR;
    ICurrency USD;
    Oracle oracle;
    Trade trade;

    MockPyth pyth;
    CurrencyVault cv;

    bytes32 EURUSD_PRICE_FEED_ID = bytes32(uint256(0x1));
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

        // deployMintAndApprove2Currencies();

        usdc = new USDC();
        // initializing needed currencyVault..
        pyth = new MockPyth(1, 1);
        oracle = new Oracle(address(pyth));
        CurrencyVault.CurrencyInfo memory CI = CurrencyVault.CurrencyInfo({
            currencyID: 0,
            currencyName: "USD DOLLAR", // this is what i guess makes it bigger? // for now i amke this smaller, as we want this to be smaller>>
            currencyCode: "USD",
            currencyAddr: address(0x0),
            pythFeedID: bytes32(0),
            currentPrice: 0,
            lastUpdated: block.timestamp,
            active: true
        });
        cv = new CurrencyVault(address(oracle), address(usdc), owner, CI);
        trade = new Trade(address(oracle), owner, address(cv));
        // we will have EUR an
        initializeVaultAndPythEUR();

        // testie..
        address hookAddress = address(
            uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG)
        );

        deployCodeTo(
            "src/0xfxHook.sol",
            abi.encode(
                manager,
                address(usdc),
                owner,
                address(cv),
                address(trade)
            ),
            hookAddress
        );

        hook = FxHook(hookAddress);
        (alice, alicePK) = makeAddrAndKey("alice");

        approveTokens(USD);
        approveTokens(EUR);

        Currency currency2 = Currency.wrap(
            0x8006DD5dd5819d39124aBad41EEE440A3f1C373e
        );

        Currency currency3 = Currency.wrap(
            0x0552d275e243b4eE8779aDD4D65528E5b95Adc73
        );

        // initialize Pair inside trade contract

        vm.startPrank(owner);
        Trade.PairInfo memory PI = Trade.PairInfo({
            baseCurrencyID: 1,
            quoteCurrencyID: 0,
            PairName: "EURUSD",
            lastPrice: 0,
            pythFeed: EURUSD_PRICE_FEED_ID,
            updatedAt: block.timestamp,
            active: true
        });
        trade.initializePair(
            PI,
            Currency.unwrap(currency3),
            Currency.unwrap(currency2)
        );

        (key, ) = initPool(
            currency3, // EUR
            currency2, // USD
            hook,
            500,
            1,
            85549908060000000000000000000 // SQRT PRICE. == CURRENT EURUSD PRICE.. (1.165950)
        );

        PoolId poolId = key.toId();

        (uint160 sqrtPriceX962, int24 tick, , ) = manager.getSlot0(poolId);

        // mint tokens to us.

        // liquidityDelta is 100 ether, so atleast 50e17 each.

        vm.startPrank(address(cv));

        // minting eur and usd to owner.
        EUR.mint(50e17, owner);
        USD.mint(50e17, owner);

        vm.startPrank(owner);

        uint128 liquidityBefore = manager.getLiquidity(poolId);

        console.log("Liquidity Before", liquidityBefore);

        modifyLiquidityRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: TickMath.getTickAtSqrtPrice(
                    85549908060000000000000000000
                ) - 10,
                tickUpper: TickMath.getTickAtSqrtPrice(
                    85549908060000000000000000000
                ) + 10,
                liquidityDelta: 100 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );

        uint128 liquidityAfter = manager.getLiquidity(poolId);

        console.log("Liquidity After", liquidityAfter);
    }

    function approveTokens(ICurrency token) public {
        address[9] memory toApprove = [
            address(swapRouter),
            address(swapRouterNoChecks),
            address(modifyLiquidityRouter),
            address(modifyLiquidityNoChecks),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor()),
            address(actionsRouter)
        ];

        for (uint256 i = 0; i < toApprove.length; i++) {
            token.approve(toApprove[i], type(uint256).max);
        }
    }

    function initializeVaultAndPythEUR() public {
        // initialize pyth
        bytes[] memory updateData = new bytes[](1);

        updateData[0] = pyth.createPriceFeedUpdateData(
            EURUSD_PRICE_FEED_ID,
            1165950,
            10,
            -5,
            1165950,
            10,
            uint64(block.timestamp),
            uint64(block.timestamp)
        );

        uint256 fee = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{value: fee}(updateData);

        vm.startPrank(owner);
        CurrencyVault.CurrencyInfo memory C = CurrencyVault.CurrencyInfo({
            currencyID: 1,
            currencyName: "EUR",
            currencyCode: "EUR",
            currencyAddr: address(0x0),
            pythFeedID: EURUSD_PRICE_FEED_ID,
            currentPrice: 0,
            lastUpdated: 0,
            active: false
        });

        cv.initCurrency(C);
        // set USD and EUR
        CurrencyVault.CurrencyInfo memory CIEUR = cv.getCurrencyInfo(1);
        CurrencyVault.CurrencyInfo memory CIUSD = cv.getCurrencyInfo(0);

        EUR = ICurrency(CIEUR.currencyAddr);
        USD = ICurrency(CIUSD.currencyAddr);
    }

    function mintOwnerUSD() public {
        vm.startPrank(address(cv));

        EUR.mint(10e6, owner);
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
