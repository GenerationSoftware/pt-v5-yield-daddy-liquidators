/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {
    TpdaLiquidationPairFactory,
    ILiquidationSource
} from "pt-v5-tpda-liquidator/TpdaLiquidationPairFactory.sol";
import { TpdaLiquidationPair } from "pt-v5-tpda-liquidator/TpdaLiquidationPair.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IRewardSource } from "./external/interfaces/IRewardSource.sol";
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

/// @notice Thrown when a token is queried that isn't known
error UnknownRewardToken();

/// @notice Thrown when trying to initialize a token with the zero address
error CannotInitializeZeroAddress();

/// @title Reward Liquidator
/// @author G9 Software Inc.
/// @notice Liquidates rewards from a reward source.
contract RewardLiquidator is ILiquidationSource {
    using SafeERC20 for IERC20;

    /// @notice Emitted when the yield vault has been set by the creator
    /// @param yieldVault The address of the yield vault
    event YieldVaultSet(IRewardSource indexed yieldVault);

    /// @notice Emitted when the reward token has been initialized
    /// @param token The address of the reward token
    /// @param pair The address of the liquidation pair
    event InitializedRewardToken(address indexed token, TpdaLiquidationPair indexed pair);

    /// @notice The account that will set the yield vault
    address public immutable creator;

    /// @notice The vault on whose behalf this contract will contribute to the prize pool
    address public immutable vaultBeneficiary;

    /// @notice The prize pool to contribute liquidation proceeds to
    IPrizePool public immutable prizePool;

    /// @notice The factory to create liquidation pairs
    TpdaLiquidationPairFactory public immutable liquidationPairFactory;

    /// @notice The target auction period for liquidation pairs
    uint64 public immutable targetAuctionPeriod;

    /// @notice The target auction price for liquidation pairs
    uint192 public immutable targetAuctionPrice;

    /// @notice The smoothing factor for liquidation pairs
    uint256 public immutable smoothingFactor;

    /// @notice The yield vault from which this contract receives rewards
    IRewardSource public yieldVault;

    /// @notice A mapping from reward tokens to liquidation pairs
    mapping(address tokenOut => TpdaLiquidationPair liquidationPair) public liquidationPairs;

    /// @notice Construct a new RewardLiquidator
    /// @param _creator The account that will set the yield vault
    /// @param _vaultBeneficiary The vault on whose behalf this contract will contribute to the prize pool
    /// @param _prizePool The prize pool to contribute liquidation proceeds to
    /// @param _liquidationPairFactory The factory to create liquidation pairs
    /// @param _targetAuctionPeriod The target auction period for liquidation pairs
    /// @param _targetAuctionPrice The target auction price for liquidation pairs
    /// @param _smoothingFactor The smoothing factor for liquidation pairs
    constructor(
        address _creator,
        address _vaultBeneficiary,
        IPrizePool _prizePool,
        TpdaLiquidationPairFactory _liquidationPairFactory,
        uint64 _targetAuctionPeriod,
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

    /// @notice Set the yield vault to receive rewards from
    /// @param _yieldVault The yield vault to set
    function setYieldVault(IRewardSource _yieldVault) external {
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

    /// @notice Initialize a reward token for liquidation. Must be called before liquidations can be performed for this token.
    /// @param rewardToken The address of the reward token
    /// @return The liquidation pair for the reward token
    function initializeRewardToken(address rewardToken) external returns (TpdaLiquidationPair) {
        if (rewardToken == address(0)) {
            revert CannotInitializeZeroAddress();
        }
        if (address(liquidationPairs[rewardToken]) != address(0)) {
            revert AlreadyInitialized();
        }
        TpdaLiquidationPair pair = liquidationPairFactory.createPair(
            this,
            address(prizePool.prizeToken()),
            rewardToken,
            targetAuctionPeriod,
            targetAuctionPrice,
            smoothingFactor
        );
        liquidationPairs[rewardToken] = pair;

        emit InitializedRewardToken(rewardToken, pair);

        return pair;
    }

    /// @inheritdoc ILiquidationSource
    function liquidatableBalanceOf(address tokenOut) external returns (uint256) {
        yieldVault.claimRewards();
        return IERC20(tokenOut).balanceOf(address(this));
    }

    /// @inheritdoc ILiquidationSource
    function transferTokensOut(
        address,
        address receiver,
        address tokenOut,
        uint256 amountOut
    ) external returns (bytes memory) {
        if (msg.sender != address(liquidationPairs[tokenOut])) {
            revert OnlyLiquidationPair();
        }
        IERC20(tokenOut).safeTransfer(receiver, amountOut);

        return "";
    }

    /// @inheritdoc ILiquidationSource
    function verifyTokensIn(
        address,
        uint256 amountIn,
        bytes calldata
    ) external {
        prizePool.contributePrizeTokens(vaultBeneficiary, amountIn);
    }

    /// @inheritdoc ILiquidationSource
    function targetOf(address) external view returns (address) {
        return address(prizePool);
    }

    /// @inheritdoc ILiquidationSource
    function isLiquidationPair(address tokenOut, address liquidationPair) external view returns (bool) {
        address existingPair = address(liquidationPairs[tokenOut]);
        if (existingPair == address(0)) {
            revert UnknownRewardToken();
        }
        return existingPair == liquidationPair;
    }
}
