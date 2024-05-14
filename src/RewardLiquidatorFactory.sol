// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { RewardLiquidator, IPrizePool, TpdaLiquidationPairFactory } from "./RewardLiquidator.sol";

/// @title  PoolTogether V5 Reward Liquidator Factory
/// @author G9 Software Inc.
/// @notice Factory contract for deploying new reward liquidators
contract RewardLiquidatorFactory {

    ////////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when a new RewardLiquidator has been deployed by this factory.
    /// @param liquidator The address of the newly deployed RewardLiquidator
    event NewRewardLiquidator(
        RewardLiquidator indexed liquidator
    );

    /// @notice List of all liquidators deployed by this factory.
    RewardLiquidator[] public allLiquidators;

    /// @notice Mapping to verify if a Liquidator has been deployed via this factory.
    mapping(address liquidator => bool deployedByFactory) public deployedLiquidators;

    /// @notice Mapping to store deployer nonces for CREATE2
    mapping(address deployer => uint256 nonce) public deployerNonces;

    ////////////////////////////////////////////////////////////////////////////////
    // External Functions
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy a new liquidator that contributes liquidations to a prize pool on behalf of a vault.
    /// @dev Emits a `NewRewardLiquidator` event with the vault details.
    /// @param _creator The address of the creator of the vault
    /// @param _vaultBeneficiary The address of the vault beneficiary of the prize pool contributions
    /// @param _prizePool The prize pool the vault will contribute to
    /// @param _liquidationPairFactory The factory to use for creating liquidation pairs
    /// @param _targetAuctionPeriod The target auction period for liquidations
    /// @param _targetAuctionPrice The target auction price for liquidations
    /// @param _smoothingFactor The smoothing factor for liquidations
    /// @return RewardLiquidator The newly deployed RewardLiquidator
    function createLiquidator(
        address _creator,
        address _vaultBeneficiary,
        IPrizePool _prizePool,
        TpdaLiquidationPairFactory _liquidationPairFactory,
        uint64 _targetAuctionPeriod,
        uint192 _targetAuctionPrice,
        uint256 _smoothingFactor
    ) external returns (RewardLiquidator) {
        RewardLiquidator liquidator = new RewardLiquidator{
            salt: keccak256(abi.encode(msg.sender, deployerNonces[msg.sender]++))
        }(
            _creator,
            _vaultBeneficiary,
            _prizePool,
            _liquidationPairFactory,
            _targetAuctionPeriod,
            _targetAuctionPrice,
            _smoothingFactor
        );

        allLiquidators.push(liquidator);
        deployedLiquidators[address(liquidator)] = true;

        emit NewRewardLiquidator(liquidator);

        return liquidator;
    }

    /// @notice Total number of liquidators deployed by this factory.
    /// @return uint256 Number of liquidators deployed by this factory.
    function totalLiquidators() external view returns (uint256) {
        return allLiquidators.length;
    }
}
