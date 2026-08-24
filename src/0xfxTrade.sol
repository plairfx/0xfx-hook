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

    address owner;
    event PairInitialized(
        address indexed baseCurrency,
        address indexed quoteCurrency
    );

    modifier onlyOwner() {
        require(checkOwner(), "Not the owner");
        _;
    }

    mapping(address => mapping(address => PairInfo)) pairInfo;

    constructor(address _oracle, address _owner, address _cv) {
        oracle = IOracle(_oracle);
        owner = _owner;
        cv = ICurrencyVault(_cv);
    }

    // i need to also get the price from it? does it maybe not make sense to get the pairInfo fro the hook itself?

    // Hook Calls CurrencyVault currencyInfo.active
    // Hook Calls 0xfxTrade for pairInfo.active
    // CurrencyVault calls -> PYTH Oracle when initializing prices.
    // Trade needs 100% access to the PYTH oracle.
    //  ->
    // Also, we need to store the feedids,
    // for the ids like uuh..
    // we will call -> the currencyVault for the price?
    // Oracle makes sense to adjust these simply, i dont have to worry about handing 2 oracles, i can just use one.
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

        // @Importanat @DO we initialzie price now?

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
        return price.price;
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
