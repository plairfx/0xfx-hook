// SPDX-License-Identifier: MIT

import {IOracle} from "./interfaces/IOracle.sol";
import {ICurrencyVault} from "./interfaces/ICurrencyVault.sol";
import {Lib} from "./utils/0xLib.sol";
import {PythStructs} from "./interfaces/Pyth/IPyth.sol";
import {Heap} from "@openzeppelin/contracts/utils/structs/Heap.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Sign} from "./utils/0xSignature.sol";

pragma solidity ^0.8.22;

contract Trade is Sign {
    IOracle oracle;
    ICurrencyVault cv;

    struct PairInfo {
        uint256 baseCurrencyID;
        uint256 quoteCurrencyID;
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

    mapping(uint256 pairID => mapping(int24 tick => mapping(int24 tickRange => Heap.Uint256Heap))) priceInfo;
    mapping(uint256 oid => TradeInfo) tradeInfo;
    // So lets assume

    mapping(address => mapping(address => PairInfo)) pairInfo;

    constructor(address _oracle, address _owner, address _cv) {
        oracle = IOracle(_oracle);
        owner = _owner;
        cv = ICurrencyVault(_cv);
    }

    // check if any liquidity is avaliable before a trade happens:
    // - check if pair is open.
    // - Check user's liquidity/balance and see if he has enough
    // - Check liquidity.
    // - Dpeending on the trade type,

    // - Market Trade:
    // - check Liq & free Margin.
    // - Swap using the hook liquidity on the open market,
    // - Execute the trade -> Liquidity used will also be swapped with it, and hold in that if sell EUR ->  USD will be bought.
    // - User will have  less free margin, adn the trade will be opened with a potential TP,SL or others what the user has et.

    // - Limit Trade:
    // - check Free margin:
    // -  put it into limit mapping
    // - Hook beforeSwap calls to see what trade are valid to be executed at the price (Liq check , free margin check).
    // - Executes all trades  and swap ofc.

    // - Stoploss:
    // - BeforeSwap checks if any of the pairPrice is at a stoploss for a user,
    // - Calls closeTrade on an order with a privileged function.
    // - Trades get closed and user margin PNL and balance etc will get edited.

    // - TakeProfit
    // - BeforeSwap checks fi any pairPrice is close to a takeProfit.
    // - Calls CLosePosition on an position.
    // - Trades get closed and userInfo gets edited PNL etc.

    // - Liquidation:
    // - Whenever an user  freeMargin is in the minus or .
    // - BeforeSwap checks to see if any user users positio is liquidateable? ( this one we will need to go into more later).
    // - Positions get closed until an USER IS NOT underwater anymore.

    // @important:
    // Think about examples such as USD LONG, what does our vault do with the liquiidity used from the vault?
    // How will we treat limt orde rprices that have already been crossed? with the price update.
    // Add @signatures, so that the trading experience will already be nice, with the EIP712 + ECDSA with the other EIPS. (Signature EOA ETC).

    // Heaps
    // just have to see and understand how like, multiple heaps woiuld workout.

    //BEcause they would, work out ina  sense,

    //Verify if a trade is valid and possible

    // Execute swap,

    //AfterSwap checks if another trade is possible.

    //But with the heaps, if we have multiple heaps, how would search through all of them?TIck Price - Change in Price, is the price we want to search for. This would be all the heaps

    //mapping(tickprice=> Heap) heaps;

    //if we want to search an heap heap[tickPrice], but if the price change is 50 ticks, it will be 50 heaps to search for..

    // We need to group ticks together, in sense where we have to leap through as least as possible heaps. THis will make everything
    // Understanding this is the priority: What is a valid tickRange we can swipe through?
    // Without making too much of a thing, if an heap is empty we go through the next.
    // This will workout, for sure.

    // can only be the HOOK!
    function afterTrade(
        int24 tick,
        uint160 sqrtPricex96,
        PoolKey calldata key
    ) external {
        // int24 tick:
        // sqrtPricex96:
        // calculate the tickRange..
        // tickRange ->  betwene tickrange.
        // get the max range to the upperTick, and the min range down tot he lowerTick;
        // With this we are able to -> write
        // Limit Order..
        // Limit order comes in, at 1535, but the tickprice is 1536,
        // If the price goes to 1535, but the limit is registered at 1535?
        // How do we make sure the user still get executed in this example?
        //  We check the lower ranges aswell to see if there are orders registered at those prices.
        // SO lets say there is a 1535 limit order at the tickRange 10 which is 1534.5,
        // this si normally, but we will go into the both
        // higher and lower tick ranges and mkae sure they are executed.
        // In this case we have a preference towardst he currentTick.
        // We wil both get three values, of the tickrange between the sqrtPricex96 we have.
        // Whenever a trade is ranged towards we will pick the earliest trade set and execute that first.
        // TickRange 1535,
        // we will take 1533 t/m 1536, but depending ont he rpice really,
        // depended on the price which is set by the user.
        // SqrtPriceX96 = 1.16500 is between 1534 and 1535
        // TickRange = 1535
        // CurrentSQRTPRICEX96 = 1.16500 // gett he tickrange
        // getMappingInfo, Earliest order from the heap + previous tick heap that also has orders there.
        // Goal= finish the logic of limit order/stoploss/take profit/
        // These 4 should be very smiliar in terms of logic as they are the orders hat need to be executed.
        // Situation:
        // We have 3 orders:
        // Limit order 1534: tickRange: 1 of 10. last
        // Stoploss at 1534: tickrange 9 of 10. eseond earlierst
        // Limit order 1534: tickrange 9 of 10. Earliest BUY
        // Price goes to 1533 tickrange 8/10  ->
        // Execute limit Order, that are buys -> so tick + price range, and execute the earliest of them all.
        // Dpeendig on the price omvement it might get a lot of tick ranges,
        // FIrst we get the tickRange, currently
        // bool short; // we need to get the right order for this aswell tbh.
        // getTickRange(sqrtPriceX96, short);
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

        if (TR.orderType == 0 || TR.orderType == 1) {
            orderID++;

            (uint160 currentSqrtPricex96, , , ) = getSlot0Info(TR.pairID);

            if (
                (currentSqrtPricex96 >= TR.ENTRY_sqrtPriceX96 && !TR.short) ||
                ((TR.ENTRY_sqrtPriceX96 >= currentSqrtPricex96 && TR.short) ||
                    TR.orderType == 0)
            ) {
                // marketOrder..
            } else {
                // limit Order..
                (int24 tick, int24 tickRange) = getTickRange(
                    TR.ENTRY_sqrtPriceX96,
                    TR.short
                );

                Heap.Uint256Heap storage H = priceInfo[TR.pairID][tick][
                    tickRange
                ];
                Heap.insert(H, orderID);

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

            // we will add the forex ufnctionallity later,
            // now we add the orderkeeping firs

            // add logic of the mapping etc.

            // whenever a trade happens, we make sure we execute it between these ranges aswell..

            // so if a tick moves 1 up, -> we will execute the first, and see if the others are in range..
        } else if (TR.orderType == 2 || TR.orderType == 3) {
            // cancel order && modifyOrder
        } else {
            // modifyPosition & closePosition.
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
