// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {IOracle} from "./interfaces/IOracle.sol";
import {IStorage} from "./interfaces/I0xfxStorage.sol";
import {ICurrencyVault} from "./interfaces/ICurrencyVault.sol";
import {Lib} from "./utils/0xLib.sol";
import {PythStructs} from "./interfaces/Pyth/IPyth.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {Sign} from "./utils/0xSignature.sol";

contract Trade is Sign {
    IOracle oracle;
    ICurrencyVault cv;
    IStorage store;
    using CurrencyLibrary for Currency;

    struct PairInfo {
        uint256 baseCurrencyID;
        uint256 quoteCurrencyID;
        uint256 pairID;
        string PairName;
        // PoolKey pk; // add this later.
        uint256 lastPrice;
        bytes32 pythFeed;
        uint256 updatedAt;
        bool active;
    }

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
    address owner;
    uint256 lastTickPrice;
    uint256 orderID;

    event PairInitialized(
        address indexed baseCurrency,
        address indexed quoteCurrency
    );

    modifier onlyOwner() {
        require(checkOwner(), "Not the owner");
        _;
    }
    uint24 tickLength = 20;

    mapping(uint256 oid => TradeInfo) tradeInfo;
    mapping(address user => UserInfo) userInfo;
    // So lets assume

    mapping(address => mapping(address => PairInfo)) pairInfo;

    constructor(address _oracle, address _owner, address _cv) {
        oracle = IOracle(_oracle);
        owner = _owner;
        cv = ICurrencyVault(_cv);
    }

    function afterTrade(
        int24 tick,
        uint160 sqrtPricex96,
        PoolKey calldata key
    ) external {
        // Liquidaiton will be implemented later on..

        // we convert to a tickRange
        // @Important get a more logically approach for the tickRange..
        uint256 pairID = pairInfo[Currency.unwrap(key.currency0)][
            Currency.unwrap(key.currency0)
        ].pairID;
        (int24 userTick, int24 tickrange) = getTickRange(sqrtPricex96, false);
        uint256 oidToExecute;
        try store.getFirstOrderOut(pairID, tick, tickrange) {
            // check user's margin..
            TradeInfo memory TI = tradeInfo[oidToExecute];
            if (doesUserHaveEnoughMargin(TI.user)) {
                oidToExecute = store.popFirstOrder(pairID, tick, tickrange);
            } else {
                return;
            }
        } catch {
            return;
        }

        // check if the vault has enough liquidity to execute...

        // execute the swap.
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

            (uint160 currentSqrtPricex96, , , ) = getSlot0Info(TR.pairID);

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
    ) external {
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

        emit PairInitialized(baseCurrency, quoteCurrency);
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

    function checkOwner() internal view returns (bool) {
        return owner == msg.sender;
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
    }

    function getMargin() internal view returns (uint256) {}

    function getPNL() internal view returns (int256) {
        // the same it uses info from swapMath etc.
    }

    function getPairInfo(
        address currency0,
        address currency1
    ) public view returns (PairInfo memory) {
        return pairInfo[currency0][currency1];
    }

    function getSlot0Info(
        uint256 pairID
    )
        internal
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint24 protocolFee,
            uint24 lpFee
        )
    {
        // call the hookInfo function.
    }
}
