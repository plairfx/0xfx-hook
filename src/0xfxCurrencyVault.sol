// SDPX-License-Identifier: MIT

import {CurrencyFX} from "./0xfxCurrency.sol";
import {ICurrency} from "./interfaces/ICurrency.sol";
import {IPyth, PythStructs} from "./interfaces/Pyth/IPyth.sol";
import {IOracle} from "./interfaces/IOracle.sol";

import {
    ReentrancyGuardTransient
} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

pragma solidity ^0.8.22;
contract CurrencyVault is ReentrancyGuardTransient {
    using SafeERC20 for ICurrency;

    IOracle oracle;
    ICurrency currency;

    address owner;
    address immutable USDC;
    uint256 valid_time_distance = 60; // 60seconds..

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
    mapping(address => uint256 currencyID) currencyIdInfo;

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

    modifier onlyVaultOwner() {
        require(checkVaultOwner(), "Not the owner");
        _;
    }

    /// @notice initializes the pyth oracle, usdc and owner.
    constructor(
        address _oracle,
        address usdc,
        address _owner,
        CurrencyInfo memory C
    ) {
        oracle = IOracle(_oracle);
        USDC = usdc;
        owner = _owner;

        CurrencyFX newToken = new CurrencyFX{
            salt: keccak256(abi.encode(C.currencyName))
        }(C.currencyName, C.currencyCode, address(this));

        // USDC = ACTIVE
        currencies[0] = C;
        currencies[0].currencyAddr = address(newToken);

        emit CurrencyInitialized(address(newToken));
    }

    /// @dev deposits USDC -> to any intialized Currency,
    /// the currency rate being used is depended
    /// at the moment we are assuming USD as the quoteCurrrency.
    /// any issues with nonQuoted USDC currencies are valid.
    function deposit(
        uint256 cid,
        uint256 amount,
        bytes memory signature,
        uint256 deadline
    ) external nonReentrant {
        //  check currencyPair,
        require(currencies[cid].active, "Currency Not Active");
        require(amount > 0, "Cant be Zero");
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
        uint256 price;
        if (cid == 0) {
            price = 1e6; // 1 USD == 1 USDC!
        } else {
            price = uint256((getCurrentPrice(ci.pythFeedID)));
        }

        ICurrency(USDC).safeTransferFrom(msg.sender, address(this), amount);
        ICurrency(ci.currencyAddr).mint((amount / price), msg.sender);

        emit Deposited(msg.sender, amount, ci.currencyAddr);
    }

    /// @dev withdraws any intialized currency -> USDC.
    /// the currency rate being used is depended on the PYTH oracle.
    /// at the moment we are assuming USD as the quoteCurrrency.
    // any issues with nonQuoted USDC currencies are valid.
    function withdraw(uint256 cid, uint256 amount) external nonReentrant {
        require(currencies[cid].active, "Currency Not Active");
        CurrencyInfo memory ci = currencies[cid];
        require(
            ICurrency(ci.currencyAddr).balanceOf(msg.sender) >= amount &&
                amount > 0,
            "Not Enough Balance"
        );

        uint256 price = uint256(getCurrentPrice(ci.pythFeedID));

        // EUR -> USD
        ICurrency(ci.currencyAddr).burn(amount, msg.sender);
        ICurrency(USDC).safeTransfer(msg.sender, amount * price);

        emit Withdrawn(msg.sender, amount * price, ci.currencyAddr);
    }

    /// @notice intializes the currency for use.
    // calls Pyth oracle price feed to confirm if the priceFeed exists.
    function initCurrency(CurrencyInfo memory c) external onlyVaultOwner {
        // currency cannot be active
        require(!currencies[c.currencyID].active, "Currency Already Active!");

        // call pyth oracle and test if it works! we can get the price back;

        c.currentPrice = uint256(getCurrentPrice(c.pythFeedID));

        CurrencyFX newToken = new CurrencyFX(
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

    /// @dev gets current price of an currency from the pyth oracle.
    /// @notice it reverts if the price is stale (outdated than the valid_time_distance).
    function getCurrentPrice(bytes32 feedID) internal view returns (int256) {
        PythStructs.Price memory price;

        try oracle.getCurrentPrice(feedID, valid_time_distance) {
            price = oracle.getCurrentPrice(feedID, valid_time_distance);
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

    function getCurrencyInfo(
        uint256 cid
    ) public view returns (CurrencyInfo memory) {
        return currencies[cid];
    }

    function getCurrencyIDInfo(address cidAddr) public view returns (uint256) {
        return currencyIdInfo[cidAddr];
    }
}
