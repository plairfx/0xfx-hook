// SDPX-License-Identifier: MIT

import {Currency} from "./0xfxCurrency.sol";
import {ICurrency} from "./interfaces/ICurrency.sol";
import {IPyth, PythStructs} from "./interfaces/Pyth/IPyth.sol";
// import {PythStructs} from "./interfaces/Pyth/PythStructs.sol";

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
    address owner;
    address immutable USDC;

    // @note add a timestamp in seconds variable for the stale price check..
    uint256 valid_time_distance = 60; // 60seconds..

    modifier onlyVaultOwner() {
        require(checkVaultOwner(), NotTheOwner());
        _;
    }
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

    error CurrencyNotActive();
    error CurrencyAlreadyActive();
    error NotEnoughCurrencyBalance();
    error NotTheOwner();
    error NotMoreThanZero();

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

    constructor(address pythAddress, address usdc, address _owner) {
        pyth = IPyth(pythAddress);
        USDC = usdc;
        owner = _owner;
    }

    function deposit(
        uint256 cid,
        uint256 amount,
        bytes memory signature,
        uint256 deadline
    ) external nonReentrant {
        //  check currencyPair,
        require(currencies[cid].active, CurrencyNotActive());
        require(amount > 0, NotMoreThanZero());
        CurrencyInfo memory ci = currencies[cid];

        // check signature
        if (deadline != 0) {
            (uint8 v, bytes32 r, bytes32 s) = getParsedSignature(signature);
            ICurrency(USDC).permit(
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
        ICurrency(ci.currencyAddr).mint((amount / price), msg.sender);

        emit Deposited(msg.sender, amount, ci.currencyAddr);
    }

    function withdraw(uint256 cid, uint256 amount) external nonReentrant {
        require(currencies[cid].active, CurrencyNotActive());
        CurrencyInfo memory ci = currencies[cid];
        require(
            ICurrency(ci.currencyAddr).balanceOf(msg.sender) >= amount &&
                amount > 0,
            NotEnoughCurrencyBalance()
        );

        uint256 price = uint256(getCurrentPrice(ci.pythFeedID));

        // EUR -> USD
        ICurrency(ci.currencyAddr).burn(amount, msg.sender);
        ICurrency(USDC).safeTransfer(msg.sender, amount * price);

        emit Withdrawn(msg.sender, amount * price, ci.currencyAddr);
    }

    function initCurrency(CurrencyInfo memory c) external onlyVaultOwner {
        // currency cannot be active
        require(!currencies[c.currencyID].active, CurrencyAlreadyActive());

        // call pyth oracle and test if it works! we can get the price back;
        c.currentPrice = uint256(getCurrentPrice(c.pythFeedID));

        Currency newToken = new Currency(
            c.currencyName,
            c.currencyCode,
            address(this)
        );
        c.currencyAddr = address(newToken);
        c.lastUpdated = block.timestamp;
        c.active = true;

        currencies[c.currencyID] = c;

        emit CurrencyInitialized(address(newToken));
    }

    function getCurrentPrice(bytes32 feedID) internal view returns (int256) {
        PythStructs.Price memory price;
        // initialize the currency

        try pyth.getPriceNoOlderThan(feedID, valid_time_distance) {
            // 20 seconds, we call this agian to save the price,
            // as we do not know if the price will revert or not.
            price = pyth.getPriceNoOlderThan(feedID, valid_time_distance + 20);
        } catch {
            // reverts if updatedTime - block.timestamp is less than  - age we set.
            revert();
        }
        return price.price;
    }

    function getParsedSignature(
        bytes memory signature
    ) internal view returns (uint8, bytes32, bytes32) {
        return ECDSA.parse(signature);
    }

    function checkVaultOwner() internal view returns (bool) {
        return owner == msg.sender;
    }
}
