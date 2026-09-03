// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {IOracle} from "./interfaces/IOracle.sol";
import {IStorage} from "./interfaces/I0xfxStorage.sol";
import {IHook} from "./interfaces/I0xfxHook.sol";
import {ICurrencyVault} from "./interfaces/ICurrencyVault.sol";
import {Lib} from "./utils/0xLib.sol";
import {PythStructs} from "./interfaces/Pyth/IPyth.sol";
import {
    ModifyLiquidityParams,
    SwapParams
} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapMath} from "@uniswap/v4-core/src/libraries/SwapMath.sol";
import {Sign} from "./utils/0xSignature.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {ICurrency} from "./interfaces/ICurrency.sol";
import {Storage} from "./0xfxStorage.sol";

contract Trade is AccessControl, Sign {
    IOracle oracle;
    ICurrency USD;
    ICurrencyVault cv;
    IStorage store;
    IHook hook;
    IPoolManager manager;
    using StateLibrary for IPoolManager;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for ICurrency;

    bytes32 constant HOOK_ROLE = keccak256("hook");
    bytes32 constant OWNER_ROLE = keccak256("owner");
    struct PairInfo {
        uint256 baseCurrencyID;
        uint256 quoteCurrencyID;
        uint256 pairID;
        string PairName;
        PoolKey pk; // add this later.
        uint256 lastPrice;
        bytes32 pythFeed;
        uint256 updatedAt;
        bool active;
    }

    bytes constant ZERO_BYTES = new bytes(0);
    struct TradeInfo {
        uint256 oid;
        uint256 pairID;
        address user;
        uint256 lotSize;
        bool short;
        uint160 entry;
        uint160 stoploss;
        uint160 takeProfit;
        uint256 marginUsed;
        uint256 entryTime;
    }

    struct UserInfo {
        uint256 balance;
        uint256 leverage;
        uint256 equity;
        uint256 freeMargin;
        uint256 margin;
    }

    // liquidity?
    event LimitPlaced();

    event Deposited(
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );

    uint256 lastTickPrice;
    uint256 orderID;

    event PairInitialized(
        address indexed baseCurrency,
        address indexed quoteCurrency
    );

    uint24 tickLength = 20;

    mapping(uint256 oid => TradeInfo) tradeInfo;
    mapping(address user => UserInfo) userInfo;
    // So lets assume

    mapping(address => mapping(address => PairInfo)) pairInfo;
    mapping(uint256 pairID => PairInfo) pairInfoID;

    constructor(address _oracle, address _owner, address _cv) {
        oracle = IOracle(_oracle);
        _grantRole(OWNER_ROLE, _owner);
        cv = ICurrencyVault(_cv);

        Storage Store = new Storage(address(this));
        store = IStorage(address(Store));
    }

    function afterTrade(
        int24 tick,
        uint160 sqrtPricex96,
        PoolKey calldata key
    ) external onlyRole(HOOK_ROLE) {
        uint256 pairID = pairInfo[Currency.unwrap(key.currency0)][
            Currency.unwrap(key.currency0)
        ].pairID;
        (int24 userTick, int24 tickrange) = getTickRange(sqrtPricex96, false);
        uint256 oidToExecute;

        TradeInfo memory TI;

        try store.getFirstOrderOut(pairID, tick, tickrange) {
            // check user's margin..
            TI = tradeInfo[oidToExecute];
            if (doesUserHaveEnoughMargin(TI.user)) {
                oidToExecute = store.popFirstOrder(pairID, tick, tickrange);
            } else {
                return;
            }
        } catch {
            return;
        }
        PoolId poolId = key.toId();

        // get the expected price, without any fees
        // to calculate the currentPrice of the lotSize calculation.
        (, uint256 c0out, uint256 c1In, ) = SwapMath.computeSwapStep({
            sqrtPriceCurrentX96: sqrtPricex96,
            sqrtPriceTargetX96: 4295128739 + 1,
            liquidity: manager.getLiquidity(key.toId()),
            amountRemaining: 1000000,
            feePips: 0
        });

        // get the amountSpecified that we want to use,
        // Lotsize * 1e6 if short
        // Else  example: Lotsize * c1In(1.17570).
        int amountSpecified = int256(TI.lotSize) *
            int256((TI.short ? 1e6 : c1In));

        BalanceDelta BD = hook.swap(
            key,
            SwapParams({
                zeroForOne: TI.short ? false : true,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: 4295128739 + 1
            }),
            ZERO_BYTES
        );

        // add to position etc..
        TradeInfo storage te = tradeInfo[oidToExecute];
        te.entryTime = block.timestamp;

        // Logic here:
        // If short we sell, meaning ->  amount0 is gonna be negative, so we want to get rid of EUR
        // and vice versa.
        te.entry = uint160(
            uint128(
                te.short
                    ? -BD.amount0() / BD.amount1()
                    : BD.amount0() / -BD.amount1()
            )
        );
    }

    function depositUSD(
        address receiver,
        uint256 amount,
        uint256 deadline,
        bytes memory signature
    ) external {
        // checks
        require(
            USD.balanceOf(msg.sender) >= amount && amount > 0,
            "Not Enough Balance"
        );

        UserInfo storage UI = userInfo[receiver];
        UI.balance += amount;
        UI.equity += amount;
        UI.freeMargin += amount;

        (uint8 v, bytes32 r, bytes32 s) = Lib.getParsedSignature(signature);

        if (deadline != 0) {
            USD.permit(msg.sender, address(this), amount, deadline, v, r, s);
        }

        USD.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, msg.sender, amount);
    }

    // MarketOrder
    // Limit Order
    // CancelOrder
    // ModifyOrdr
    // ModifyPosition
    // Close Position
    function trade(TradeRequest memory TR, bytes memory signature) external {
        // VerifySignature first.
        require(
            Sign.getSigner(signature, Sign.getTradeHash(TR), TR.user),
            "Invalid Signature/Signer"
        );
        // Check if user has enough USDC deposited.
        // for this we have an expectation of the same margin.

        if (TR.orderType == 0 || TR.orderType == 1) {
            orderID++;
            PoolId ID = pairInfoID[TR.pairID].pk.toId();
            (uint160 currentSqrtPricex96, , , ) = manager.getSlot0(ID);

            if (
                (currentSqrtPricex96 >= TR.ENTRY_sqrtPriceX96 && !TR.short) ||
                ((TR.ENTRY_sqrtPriceX96 >= currentSqrtPricex96 && TR.short) ||
                    TR.orderType == 0)
            ) {
                // marketOrder..
                // check if user has enough margin...
            } else {
                // limit Order..
                (int24 tick, int24 tickRange) = getTickRange(
                    TR.ENTRY_sqrtPriceX96,
                    TR.short
                );

                store.insertOrder(TR.pairID, tick, tickRange, orderID);

                uint256 margin;
                tradeInfo[orderID] = TradeInfo({
                    oid: orderID,
                    pairID: TR.pairID,
                    user: TR.user,
                    lotSize: TR.lotSize,
                    short: TR.short,
                    entry: TR.ENTRY_sqrtPriceX96,
                    stoploss: TR.SL_sqrtPriceX96,
                    takeProfit: TR.TP_sqrtPriceX96,
                    marginUsed: margin,
                    entryTime: block.timestamp
                });

                emit LimitPlaced();
            }
        } else if (TR.orderType == 2 || TR.orderType == 3) {
            // cancel order && modifyOrder
        } else {
            // modifyPosition & closePosition.
            // whenever a modifyPosition or closePosition happens,
            // we expect some swap to happen depending on the vault.
            // As we have not figured out the Vault and uuh logic of the liquidaiton etc..
            // WE are going to keep it a basic template ->
        }
    }

    function getTickRange(
        uint160 sqrtPriceX96,
        bool short
    ) internal view returns (int24, int24) {
        int24 userTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        uint160 prevTickPrice = TickMath.getSqrtPriceAtTick(userTick - 1) + 1; // -1
        uint160 nextTickprice = TickMath.getSqrtPriceAtTick(userTick + 1) - 1; // -1

        uint24 tickInterval;

        tickInterval = uint24((nextTickprice - prevTickPrice) / tickLength);

        uint256 tickIntervalUser = uint160(sqrtPriceX96 - prevTickPrice);

        if (short) {
            return (
                userTick,
                int24(
                    int256(
                        FixedPointMathLib.divWadUp(
                            tickIntervalUser,
                            tickInterval
                        ) / 1e18
                    )
                )
            );
        } else {
            return (
                userTick,
                int24(
                    int256(
                        FixedPointMathLib.sDivWad(
                            int256(tickIntervalUser),
                            int256(int24(tickInterval))
                        ) / 1e18
                    )
                )
            );
        }
    }

    function initializePair(
        PairInfo memory PI,
        address baseCurrency,
        address quoteCurrency
    ) external onlyRole(OWNER_ROLE) {
        require(
            !pairInfo[baseCurrency][quoteCurrency].active &&
                !pairInfo[quoteCurrency][baseCurrency].active,
            "Cannot be active"
        );

        // Both currencies need to be active..
        Lib.CurrencyInfo memory c0 = cv.getCurrencyInfo(PI.baseCurrencyID);
        Lib.CurrencyInfo memory c1 = cv.getCurrencyInfo(PI.quoteCurrencyID);
        require(c0.active && c1.active, "Currencies have to be active");

        // Test if the actual feed even exists...
        getCurrentPrice(PI.pythFeed, 60); // 60 seconds..

        PairInfo storage Pe = pairInfo[baseCurrency][quoteCurrency];

        Pe.active = true;
        Pe.pythFeed = PI.pythFeed;
        Pe.PairName = PI.PairName;
        Pe.baseCurrencyID = PI.baseCurrencyID;
        Pe.quoteCurrencyID = PI.quoteCurrencyID;
        Pe.updatedAt = block.timestamp;
        Pe.pk = PI.pk;
        address managerAddr = address(manager);

        pairInfoID[PI.pairID] = Pe;
        // Approve the currencies to the manager to the max

        emit PairInitialized(baseCurrency, quoteCurrency);
    }

    function initHookRole(address _hook) external onlyRole(OWNER_ROLE) {
        require(address(hook) == address(0x0), "Already intialized hook");
        _grantRole(HOOK_ROLE, _hook);
        hook = IHook(_hook);
    }

    // @fix initPairKeyID funciton
    function initPairKeyID(
        address baseCurrency,
        address quoteCurrency,
        PoolKey calldata key
    ) external onlyRole(HOOK_ROLE) {
        PairInfo memory PI = pairInfo[baseCurrency][quoteCurrency];
        pairInfo[baseCurrency][quoteCurrency].pk = key;
        pairInfoID[PI.pairID].pk = key;
    }

    function getCurrentPrice(
        bytes32 feedID,
        uint256 validUpdateTime
    ) internal view returns (int256) {
        PythStructs.Price memory price;

        try oracle.getCurrentPrice(feedID, validUpdateTime) {
            price = oracle.getCurrentPrice(feedID, validUpdateTime);
        } catch {
            // reverts if updatedTime - block.timestamp is less than  - age we set.
            revert();
        }
        return price.price; // we need to add the confidence of the price with it.
        // @IMPORTANT
        // so if its  a short it will be +  and - for the short.
    }

    function doesUserHaveEnoughMargin(
        address user
    ) internal view returns (bool) {
        // get the outputs for multiple prices?
        // we need prices of all pairs, for now we start is EURUSD
        // swapMath.computeSwapStep,
        // calculate the price by simply doing a math formula and get the currentPrice
        // lotsize * price, and we have our currentMargin of  a position
        // calculate users pnl positions
        // see if user has enough Margin and done..
        // we cna already compute hte prices of everything, we simply already get all our prices..

        // needs to implemented, returns true for  now.
        return true;
    }

    function getMargin() internal view returns (uint256) {}

    function getPNL() internal view returns (int256) {}

    function getPairInfo(
        address currency0,
        address currency1
    ) public view returns (PairInfo memory) {
        return pairInfo[currency0][currency1];
    }
}
