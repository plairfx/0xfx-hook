// SDPX-License-Identifier: MIT

import {Test} from "forge-std/Test.sol";
import {USDC} from "../mocks/USDC.sol";
import {MockPyth} from "../mocks/MockPyth.sol";
import {CurrencyVault} from "../../src/0xfxCurrencyVault.sol";

pragma solidity 0.8.34;

contract CurrencyVaultBase is Test {
    MockPyth pyth;
    USDC usdc;
    CurrencyVault cv;

    bytes32 EURUSD_PRICE_FEED_ID = bytes32(uint256(0x1));
    bytes32 GBP_PRICE_FEED_ID = bytes32(uint256(0x2));

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    function setUp() external {
        usdc = new USDC();
        pyth = new MockPyth(1, 1);
        cv = new CurrencyVault(address(pyth), address(usdc), owner);
    }

    function initializePyth() public {
        bytes[] memory updateData = new bytes[](1);

        updateData[0] = pyth.createPriceFeedUpdateData(
            EURUSD_PRICE_FEED_ID,
            116595,
            10,
            -5,
            116595,
            10,
            uint64(block.timestamp),
            uint64(block.timestamp)
        );

        uint256 fee = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{value: fee}(updateData);
    }

    function initializedCurrency() public {
        vm.startPrank(owner);
        CurrencyVault.CurrencyInfo memory C = CurrencyVault.CurrencyInfo({
            currencyID: 1,
            currencyName: "EURO",
            currencyCode: "EUR",
            currencyAddr: address(0x0),
            pythFeedID: EURUSD_PRICE_FEED_ID,
            currentPrice: 0,
            lastUpdated: 0,
            active: false
        });
        vm.expectEmit();
        emit CurrencyVault.CurrencyInitialized(
            0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2
        ); // not predicting the addr..
        cv.initCurrency(C);
    }
}
