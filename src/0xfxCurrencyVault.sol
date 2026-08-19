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
    using SafeERC20 for ICurrency;
    ICurrency currency;
    address immutable USDC;

    event Deposited(
        address indexed user,
        uint256 amount,
        address indexed currency
    );

    event Withdrawn(
        address indexed user,
        uint256 amount,
        address indexed currency
    );
    event CurrencyInitialized(address indexed currency);

    bytes immutable empty_signature;

    error CurrencyNotActive();
    error CurrencyAlreadyActive();
    error NotEnoughCurrencyBalance();

    struct CurrencyInfo {
        uint256 currencyID;
        string currencyName;
        string currencyCode;
        address currencyAddr;
        bytes32 pythFeedID;
        uint256 currentPrice;
        uint256 lastUpdated;
        bool active;
    }

    mapping(uint256 currencyID => CurrencyInfo) currencies;

    constructor(address pythAddress) {
        pyth = IPyth(pythAddress);
    }

    function deposit(
        uint256 cid,
        uint256 amount,
        bytes memory signature
    ) external nonReentrant {
        //  check currencyPair,
        require(currencies[cid].active, CurrencyNotActive());
        CurrencyInfo memory ci = currencies[cid];

        // check signature
        if (keccak256(signature) != keccak256(empty_signature)) {
            (uint8 v, bytes32 r, bytes32 s) = getParsedSignature(signature);
            ICurrency(ci.currencyAddr).permit(
                msg.sender,
                address(this),
                amount,
                deadline,
                v,
                r,
                s
            );
        }
        // get updatedPyth price.
        uint256 price = uint256(getCurrentPrice(ci.pythFeedID));

        ICurrency(USDC).safeTransferFrom(msg.sender, address(this), amount);
        ICurrency(ci.currencyAddr).mint((amount / price), receiver);

        emit Deposited(msg.sender, amount, ci.currencyAddr);
    }

    function withdraw(uint256 cid, uint256 amount) external nonReentrant {
        require(currencies[cid].active, CurrencyNotActive());
        CurrencyInfo memory ci = currencies[cid];
        require(
            ICurrency(ci.currencyAddr).balanceOf(msg.sender) >= amount,
            NotEnoughCurrencyBalance()
        );

        uint256 price = uint256(getCurrentPrice(ci.pythFeedID));

        ICurrency(ci.currencyAddr).burn(amount, msg.sender);
        ICurrency(USDC).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, ci.currencyAddr);
    }

    function initCurrency(CurrencyInfo memory c) external {
        // currency cannot be active
        require(!currencies[c.currencyID].active, CurrencyAlreadyActive());

        // call pyth oracle and test if it works! we can get the price back;
        c.currentPrice = uint256(getCurrentPrice(c.pythFeedID));

        Currency newToken = new Currency(c.currencyName, c.currencyCode);
        c.currencyAddr = address(newToken);
        c.lastUpdated = block.timestamp;

        currencies[c.currencyID] = c;

        emit CurrencyInitialized(address(newToken));
    }

    function getCurrentPrice(bytes32 feedID) internal view returns (int256) {
        PythStructs.Price price;
        // initialize the currency

        try price = pyth.getPriceNoOlderThan(feedID, 10) {} catch {
            // @info, i assume with a stale price is reverts..
            // but lets confirm this byhand.
            revert();
        }
        // convert it to the right decimals...
        // we always want to assume to upper part of the confidence,
        // so if somebody wants to mint EUR, they need pay  oracle price + confidence.

        // @Stale prices/ Weekend closes? how does that work? return a stale price?
        // we have to check what a stale price is meant to be ..

        return price.price;
    }

    function getParsedSignature(
        bytes memory signature
    ) public view returns (uint8, bytes32, bytes32) {
        return ECDSA.parse(signature);
    }
}
