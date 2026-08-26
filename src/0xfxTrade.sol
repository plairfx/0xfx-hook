// SPDX-License-Identifier: MIT

import {IOracle} from "./interfaces/IOracle.sol";
import {ICurrencyVault} from "./interfaces/ICurrencyVault.sol";
import {Lib} from "./utils/0xLib.sol";
import {PythStructs} from "./interfaces/Pyth/IPyth.sol";
import {Heap} from "@openzeppelin/contracts/utils/structs/Heap.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

pragma solidity ^0.8.22;

contract Trade {
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

    // liquidity?

    address owner;
    uint256 lastTickPrice;

    event PairInitialized(
        address indexed baseCurrency,
        address indexed quoteCurrency
    );

    modifier onlyOwner() {
        require(checkOwner(), "Not the owner");
        _;
    }

    mapping(uint256 pairID => mapping(uint24 tick => mapping(uint24 tickRange => Heap.Uint256Heap))) priceInfo;
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
    }

    function trade(uint160 sqrtPriceX96, uint256 pairID) external {
        // limit order placed..

        uint160 currentSqrtpricex96;
        int24 userTick;

        // check if its a long/short, and if its straigth up executbale
        // get the 2 ticks -1

        int24 previoustick;
        userTick - 1;
        int24 nextTick = userTick + 1;

        // get both SqrtPricesRanges.
        // we put either 0-10 or -1 -> -10
        uint160 lowerTickPrevPrice;
        uint160 higherTickNextPrice;

        uint160 previousTickPricePlus1 = sqrtPriceX96 - lowerTickPrevPrice / 10;
        uint160 higherTickPriceMinus1 = sqrtPriceX96 - higherTickNextPrice / 10;

        int userTickRange;

        // make a formula that gets the users range
        //  -9, which means 1 tickRange of the previosu tick.

        // priceInfo[pairId][userTick][-9] put here into the heap the user's
        // orderID.

        // and voila it should be agood one fort his.

        // @amke sure to check the math with this. and double check the formulas.

        // // put it into a mapping.
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
}
