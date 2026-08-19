// SDPX-License-Identifier: MIT

import {Currency} from "./0xfxCurrency.sol";
import {ICurrency} from "./interfaces/ICurrency.sol";
import {IPyth, IPythStructs} from "./interfaces/Pyth/IPyth.sol";

import {
    ReentrancyGuardTransient
} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

pragma solidity 0.8.34;

contract CurrencyVault is ReentrancyGuardTransient {
    IPyth pyth;
    ICurrency currency;

    event Deposited(address indexed user, uint256);
    event CurrencyInitialized(address indexed currency);

    bytes immutable empty_signature;

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

    function deposit(
        uint256 cid,
        bytes memory signature
    ) external nonReentrant {
        //  check currencyPair,
        require(currencies[cid].active, CurrencyNotActive());
        CurrencyInfo memory ci = currencies[cid];

        // check signature
        if (keccak256(signature) != keccak256(empty_signature)) {
            (uint8 v, bytes32 r, bytes32 s) = getParsedSignature(signature);
            ICurrency(ci.currencyAddr).permit(
                owner,
                spender,
                value,
                deadline,
                v,
                r,
                s
            );
        }
        // get updatedPyth price.

        // do we mint it through his account.
    }

    function withdraw() external nonReentrant {}

    function initCurrency(CurrencyInfo memory c) external {
        // currency cannot be active
        require(!currencies[c.currencyID].active, CurrencyAlreadyActive());

        // call pyth oracle and test if it works! we can get the price back;

        PythStructs.Price price;
        // initialize the currency

        try price = pyth.getPriceNoOlderThan(c.pythFeedID, 10) {} catch {
            revert();
        }
        c.currentPrice = price.price;
        Currency newToken = new Currency(c.currencyName, c.currencyCode);
        c.currencyAddr = address(newToken);
        currencies[c.currencyID] = c;

        // implement the confidence part? of pyth seems ot be a topic interesting.
    }

    function getParsedSignature(
        bytes memory signature
    ) public view returns (uint8, bytes32, bytes32) {
        return ECDSA.parse(signature);
    }
}
