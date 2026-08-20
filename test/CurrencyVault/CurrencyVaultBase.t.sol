// SDPX-License-Identifier: MIT

import {Test} from "forge-std/Test.sol";
import {USDC} from "../mocks/USDC.sol";
import {MockPyth} from "../mocks/MockPyth.sol";
import {CurrencyVault} from "../../src/0xfxCurrencyVault.sol";

pragma solidity ^0.8.22;

contract CurrencyVaultBase is Test {
    MockPyth pyth;
    USDC usdc;
    CurrencyVault cv;

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    bytes32 EURUSD_PRICE_FEED_ID = bytes32(uint256(0x1));
    bytes32 GBP_PRICE_FEED_ID = bytes32(uint256(0x2));

    address owner = makeAddr("owner");
    uint256 alicePK;
    address alice;
    function setUp() external {
        usdc = new USDC();
        pyth = new MockPyth(1, 1);
        cv = new CurrencyVault(address(pyth), address(usdc), owner);
        (alice, alicePK) = makeAddrAndKey("alice");
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

    function mintAliceUSDC() public {
        usdc.mint(alice, 100e6);
    }
    function getDepositUSDCSignature(
        Permit memory P
    ) public view returns (bytes memory) {
        bytes32 GH = getUSDCMessage(P);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePK, GH);

        return abi.encodePacked(r, s, v);
    }

    function aliceDeposited10USDCForEUR() public {
        initializePyth();
        initializedCurrency();
        mintAliceUSDC();

        vm.startPrank(alice);

        uint256 deadline = block.timestamp + 10 minutes;
        uint256 amount = 10e6;
        bytes memory signature = getDepositUSDCSignature(
            Permit({
                owner: alice,
                spender: address(cv),
                value: amount,
                nonce: usdc.nonces(alice),
                deadline: deadline
            })
        );

        cv.deposit(1, amount, signature, deadline);
    }

    function getUSDCMessage(Permit memory P) public view returns (bytes32) {
        return (
            keccak256(
                abi.encodePacked(
                    hex"1901",
                    usdc.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            P.owner,
                            P.spender,
                            P.value,
                            usdc.nonces(P.owner),
                            P.deadline
                        )
                    )
                )
            )
        );
    }
}
