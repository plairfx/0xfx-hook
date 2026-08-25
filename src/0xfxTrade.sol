// SPDX-License-Identifier: MIT

import {IOracle} from "./interfaces/IOracle.sol";
import {ICurrencyVault} from "./interfaces/ICurrencyVault.sol";
import {Lib} from "./utils/0xLib.sol";
import {PythStructs} from "./interfaces/Pyth/IPyth.sol";

pragma solidity ^0.8.22;

contract Trade {
    IOracle oracle;
    ICurrencyVault cv;
    struct PairInfo {
        uint256 baseCurrencyID;
        uint256 quoteCurrencyID;
        string PairName;
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

    mapping(address => mapping(address => PairInfo)) pairInfo;
    // mappings for all the orders? => array or something?
    // and afterwards we check if the orders are already fulfilled or not.
    // mapping poolsKeys? => so we can get the lastTickPrice.

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

    // can only be the HOOK!
    function beforeTrade() external {
        // How do we intend to handle FIFO orderbook?
        // Because if we are meant to handle, the first coming order.
        // Not all orders are able to be handled,
        // Sort out orders, first ones in, will be handled first?
        // If there is any market impact during that order.
        // users that are later can be out at a worse price than expected,  becauase it is all depended uppon the pools price.
        // get all the orders at the price.
        // execute the ones with the earliest block.timestamp.
        // get the currentPrice?
        // If we have only BeforeSwap,  it will be executed whenever a new 'trade happens' while the price lays low upon that level.
        // if we do afterswap, we have 2 moments to focus upon.
        // I am an user that wants to buy 100 EUR/USD,
        // if the beforeSwap handles this and executes 100's of orders , this swap will revert 99% of the time.
        // the prpoblem with this would be litteraly be, users will be priced out and the function could get DOS, depending on the how many uhm//
        // orders there are in the price range.
        // If we implement it as an afterSwap, we would be able to execute it at the price after the swap without impacting the user tha tis swapping
        // with reverting as his LImitSqrtPricex96 is reached.
        // we initiate the cycle by the first afterSwap -> this will always initiate a swap.
        // But the hting i am having a problem with:
        // WE need to know the first order of all types or orders;
        // Limits, takeprofit,
        // Liquidations first after an swap,
        // Becuase liquidatons are the most important to safekeep the vault from experiencing a bigger loss.
        // FIFO?
        // combine all orders (Last price + change of price) in that sort we will get all the orders.
        // Whenever the first orders is executed, -> afterSwap will be executed again ->
        // get all orders within the priceRange, safe the last orders, and add the last used price +- the change, and
        // get those new orders.
        // This loop will continue until?
        // - no orders are remaining within the priceRange.
        // using the tickPrice/LastTickprice.
        // This is a good one...
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
