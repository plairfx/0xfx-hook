// SDPX-License-Identifier: MIT

import {Currency} from "./0xfxCurrency.sol";
import {IPyth, IPythStructs} from "./interfaces/Pyth/IPyth.sol";

pragma solidity 0.8.34;

contract CurrencyVault {
    IPyth pyth;

    event Deposited(address indexed user, uint256);
    event CurrencyInitialized(address indexed currency);

    error CurrencyNotActive();
    error CurrencyAlreadyActive();

    struct CurrencyInfo {
        uint256 currencyID;
        string currencyName;
        string currencyCode;
        address currencyAddr;
        uint256 pythFeedID;
        uint256 currentPrice;
        uint256 lastUpdated;
        bool active;
    }

    mapping(uint256 currencyID => CurrencyInfo) currencies;
    // the vault will support currencies,

    // user can deposit USDC for any of the currencies avaliable,
    // the pricing is powered through pyth oracle.
    // if the price is not up to date we will not allow users to mint,
    // they can if they want purchase it through the open-market instead.
    // as everyone else can.

    constructor(address pythAddress) {
        pyth = IPyth(pythAddress);
    }

    function deposit(uint256 cid) external {
        //  check currencyPair,
        require(currencies[cid].active, CurrencyNotActive());

        // getPool price and currentPrice from the pythOracle.
        // the goal is to use the currentprice mostly to let it corralate a lot more through the real life price aswell.

        // Now getting the his tokens
        // the user can choose to receive his token on the platform?
        // or
        // do we mint it through his account.
    }

    // let it be similiar for the user?
    // if pyth pricing is unactive/ (weekend ) -> how do we do this?

    function withdraw() external {}

    // ERC1155 would make sense to handle multiple tokens in 1 simple pool,
    // get the minting out of it -> and give an use case regarding this.

    // probelm wiht erc6909, is uniswap doesnt support ?

    function initCurrency(CurrencyInfo memory c) external {
        // currency cannot be active
        require(!currencies[c.currencyID].active, CurrencyAlreadyActive());

        // call pyth oracle and test if it works! we can get the price back;

        PythStructs.Price price;
        // initialize the currency

        try price = pyth.getPriceNoOlderThan(c.pythFeedID, 60) {} catch {
            revert();
        }
        c.currentPrice = price.price;
        Currency newToken = new Currency(c.currencyName, c.currencyCode);
        c.currencyAddr = address(newToken);
        currencies[c.currencyID] = c;
    }

    // i dont think disabling a currency is a goal, but for future cases we can try implementing this.

    // @Implement a signature for this, so we can use permit function.
}
