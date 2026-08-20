// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {SwapMath} from "@uniswap/v4-core/src/libraries/SwapMath.sol";
import {Hooks, IHooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    BeforeSwapDelta,
    toBeforeSwapDelta
} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {
    ModifyLiquidityParams,
    SwapParams
} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";

import {
    IERC20Minimal
} from "@uniswap/v4-core/src/interfaces/external/IERC20Minimal.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    ERC4626,
    IERC20,
    ERC20
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";
import {
    ReentrancyGuardTransient
} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

import {
    IERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICurrency} from "./interfaces/ICurrency.sol";
import {Lib} from "./utils/0xLib.sol";

contract FxHook is BaseHook, ERC20, ReentrancyGuardTransient {
    ICurrency USDC;

    using SafeERC20 for ICurrency;

    mapping(address => uint256) withdrawalCooldown;

    constructor(
        IPoolManager _IPM,
        address _USDC
    ) BaseHook(_IPM) ERC20("0xfx Liquidity Token", "0xfxLT") {
        USDC = ICurrency(address(_USDC));
    }

    uint256 immutable MAX_DEPOSIT_COOLDOWN = 30 days;
    uint256 currentDepositCoolDown = 3 days;

    uint256 liquidityUsed;

    event Transferred(
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );

    event Deposited(
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );
    event Withdrawn(
        address indexed sender,
        address indexed receiver,
        uint256 amount
    );

    event CooldownPeriodChanged(uint256 oldCD, uint256 newCD);

    // Hook
    // Vault
    // - User funds
    // - Liquidity Vault will be in this hook contract
    // - Trade ->  and user funds will be in a trade.sol file,
    // TO make sure to differentirate  between those those assets, as we dont want user funds to get entagled and worry about
    // We dont even want to have a mishap happening.
    // this function serves as the basis of the protocol.
    // We do not want to lose liquidity instantly?
    // a lockup period? cooldown period...

    // The reasonign behind all of this is ->
    // Every swap inside the beforeSwap will trigger: Limit orders, Take profits, Stoplosses, and Liquidation.
    // We stilll have to get and create the contract for that.

    function deposit(
        uint256 usdcAmount,
        uint256 deadline,
        bytes memory signature
    ) public nonReentrant returns (uint256 shares) {
        // checks
        require(USDC.balanceOf(msg.sender) >= usdcAmount, "Not Enough Balance");

        (uint8 v, bytes32 r, bytes32 s) = Lib.getParsedSignature(signature);

        uint256 _shares = _convertToShares(usdcAmount);
        withdrawalCooldown[msg.sender] = block.timestamp;

        if (deadline != 0) {
            USDC.permit(
                msg.sender,
                address(this),
                usdcAmount,
                deadline,
                v,
                r,
                s
            );
        }

        USDC.safeTransferFrom(msg.sender, address(this), usdcAmount);

        _mint(msg.sender, _shares);

        emit Deposited(msg.sender, msg.sender, usdcAmount);
    }

    // allows user to claim their LP +/+-PNL.
    // The user will need to wait for the cooldown period to expire,
    // this is made incase the period is too long for the user..

    function withdraw(
        uint256 shareAmount,
        address receiver,
        bytes memory signature
    ) external nonReentrant {
        // checks
        require(balanceOf(msg.sender) >= shareAmount, "Not Enough Balance");
        require(
            block.timestamp >= withdrawalCooldown[msg.sender],
            "Cannot Withdraw Yet"
        );

        uint256 _assets = _convertToAssets(shareAmount);

        _burn(msg.sender, shareAmount);

        // try catch instead??
        USDC.safeTransfer(msg.sender, _assets);

        emit Withdrawn(msg.sender, receiver, _assets);
    }

    // add @access control.
    function changeCooldownPeriod(uint256 newCDPeriod) external {
        require(
            MAX_DEPOSIT_COOLDOWN >= newCDPeriod,
            "Cannot be more than MAX_CD"
        );
        uint256 oldCDPeriod = currentDepositCoolDown;
        currentDepositCoolDown = newCDPeriod;

        emit CooldownPeriodChanged(oldCDPeriod, newCDPeriod);
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function asset() public view returns (address) {
        return address(USDC);
    }

    function totalAssets() public view returns (uint256) {
        return USDC.balanceOf(address(this));
    }

    function decimals() public view override returns (uint8) {
        return USDC.decimals();
    }

    function _convertToAssets(uint256 _shares) internal view returns (uint256) {
        return (_shares * totalAssets()) / totalSupply();
    }

    function _convertToShares(uint256 _assets) internal view returns (uint256) {
        return
            totalSupply() == 0
                ? _assets
                : (_assets * totalSupply()) / totalAssets();
    }

    function previewMint(uint256 _shares) public view returns (uint256) {
        return totalSupply() == 0 ? _shares : _convertToAssets(_shares);
    }

    function previewRedeem(uint256 _shares) public view returns (uint256) {
        return totalSupply() == 0 ? 0 : _convertToAssets(_shares);
    }

    function previewDeposit(uint256 _assets) public view returns (uint256) {
        return _convertToShares(_assets);
    }

    function _beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata P,
        bytes calldata
    )
        internal
        override
        returns (bytes4 selector_, BeforeSwapDelta bfd_, uint24 _swapFee)
    {
        selector_ = IHooks.beforeSwap.selector;
    }
}
