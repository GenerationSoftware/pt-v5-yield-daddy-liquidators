/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AaveV3ERC4626 } from "yield-daddy/aave-v3/AaveV3ERC4626.sol";
import {
    TpdaLiquidationPairFactory,
    ILiquidationSource
} from "pt-v5-tpda-liquidator/TpdaLiquidationPairFactory.sol";
import { TpdaLiquidationPair } from "pt-v5-tpda-liquidator/TpdaLiquidationPair.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IPrizePool } from "./external/interfaces/IPrizePool.sol";

/// @notice Thrown when a function is called by an account that isn't the creator
error OnlyCreator();

/// @notice Thrown when the yield vault has already been set
error YieldVaultAlreadySet();

/// @notice Thrown when the yield vault reward recipient is not the liquidator
error InvalidRewardRecipient();

/// @notice Thrown when a reward token has already been initialized
error AlreadyInitialized();

/// @notice Thrown when an account that isn't a valid liquidation pair calls the contract
error OnlyLiquidationPair();

/// @notice Emitted when a token is queried that isn't known
error UnknownRewardToken();

/// @notice Emitted when trying to initialize a token with the zero address
error CannotInitializeZeroAddress();

contract AaveV3ERC4626Liquidator is ILiquidationSource {

    /// @notice Emitted when the yield vault has been set by the creator
    /// @param yieldVault The address of the yield vault
    event YieldVaultSet(AaveV3ERC4626 indexed yieldVault);

    /// @notice Emitted when the reward token has been initialized
    /// @param token The address of the reward token
    /// @param pair The address of the liquidation pair
    event InitializedRewardToken(address indexed token, TpdaLiquidationPair indexed pair);

    using SafeERC20 for IERC20;

    address public immutable creator;
    address public immutable vaultBeneficiary;
    IPrizePool public immutable prizePool;
    TpdaLiquidationPairFactory public immutable liquidationPairFactory;
    uint256 public immutable targetAuctionPeriod;
    uint192 public immutable targetAuctionPrice;
    uint256 public immutable smoothingFactor;

    AaveV3ERC4626 public yieldVault;

    mapping(address tokenOut => TpdaLiquidationPair liquidationPair) public liquidationPairs;

    constructor(
        address _creator,
        address _vaultBeneficiary,
        IPrizePool _prizePool,
        TpdaLiquidationPairFactory _liquidationPairFactory,
        uint256 _targetAuctionPeriod,
        uint192 _targetAuctionPrice,
        uint256 _smoothingFactor
    ) {
        vaultBeneficiary = _vaultBeneficiary;
        targetAuctionPeriod = _targetAuctionPeriod;
        targetAuctionPrice = _targetAuctionPrice;
        smoothingFactor = _smoothingFactor;
        prizePool = _prizePool;
        liquidationPairFactory = _liquidationPairFactory;
        creator = _creator;
    }

    function setYieldVault(AaveV3ERC4626 _yieldVault) external {
        if (msg.sender != creator) {
            revert OnlyCreator();
        }
        if (address(yieldVault) != address(0)) {
            revert YieldVaultAlreadySet();
        }
        if (_yieldVault.rewardRecipient() != address(this)) {
            revert InvalidRewardRecipient();
        }
        yieldVault = _yieldVault;

        emit YieldVaultSet(_yieldVault);
    }

    function initializeRewardToken(address tokenOut) external returns (TpdaLiquidationPair) {
        if (tokenOut == address(0)) {
            revert CannotInitializeZeroAddress();
        }
        if (address(liquidationPairs[tokenOut]) != address(0)) {
            revert AlreadyInitialized();
        }
        TpdaLiquidationPair pair = liquidationPairFactory.createPair(
            this,
            address(prizePool.prizeToken()),
            tokenOut,
            targetAuctionPeriod,
            targetAuctionPrice,
            smoothingFactor
        );
        liquidationPairs[tokenOut] = pair;

        emit InitializedRewardToken(tokenOut, pair);

        return pair;
    }

    /**
    * @notice Get the available amount of tokens that can be swapped.
    * @param tokenOut Address of the token to get available balance for
    * @return uint256 Available amount of `token`
    */
    function liquidatableBalanceOf(address tokenOut) external returns (uint256) {
        yieldVault.claimRewards();
        return IERC20(tokenOut).balanceOf(address(this));
    }

    /// @inheritdoc ILiquidationSource
    function transferTokensOut(
        address sender,
        address receiver,
        address tokenOut,
        uint256 amountOut
    ) external returns (bytes memory) {
        if (msg.sender != address(liquidationPairs[tokenOut])) {
            revert OnlyLiquidationPair();
        }
        IERC20(tokenOut).safeTransfer(receiver, amountOut);
    }

    /// @inheritdoc ILiquidationSource
    function verifyTokensIn(
        address tokenIn,
        uint256 amountIn,
        bytes calldata transferTokensOutData
    ) external {
        prizePool.contributePrizeTokens(vaultBeneficiary, amountIn);
    }

    /// @inheritdoc ILiquidationSource
    function targetOf(address) external returns (address) {
        return address(prizePool);
    }

    /// @inheritdoc ILiquidationSource
    function isLiquidationPair(address tokenOut, address liquidationPair) external returns (bool) {
        address existingPair = address(liquidationPairs[tokenOut]);
        if (existingPair == address(0)) {
            revert UnknownRewardToken();
        }
        return existingPair == liquidationPair;
    }
}
