// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AaveV3ERC4626Liquidator, IPrizePool, TpdaLiquidationPairFactory } from "./AaveV3ERC4626Liquidator.sol";

/// @title  PoolTogether V5 Aave V3 ERC4626 Yield Daddy Liquidator Factory
/// @author G9 Software Inc.
/// @notice Factory contract for deploying new Aave V3 liquidators
contract AaveV3ERC4626LiquidatorFactory {

    ////////////////////////////////////////////////////////////////////////////////
    // Events
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when a new AaveV3ERC4626Liquidator has been deployed by this factory.
    /// @param liquidator The address of the newly deployed AaveV3ERC4626Liquidator
    event NewAaveV3ERC4626Liquidator(
        AaveV3ERC4626Liquidator indexed liquidator
    );

    /// @notice List of all liquidators deployed by this factory.
    AaveV3ERC4626Liquidator[] public allLiquidators;

    /// @notice Mapping to verify if a Liquidator has been deployed via this factory.
    mapping(address liquidator => bool deployedByFactory) public deployedLiquidators;

    /// @notice Mapping to store deployer nonces for CREATE2
    mapping(address deployer => uint256 nonce) public deployerNonces;

    ////////////////////////////////////////////////////////////////////////////////
    // External Functions
    ////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy a new liquidator that contributes liquidations to a prize pool on behalf of a vault.
    /// @dev Emits a `NewAaveV3ERC4626Liquidator` event with the vault details.
    /// @param _creator The address of the creator of the vault
    /// @param _vaultBeneficiary The address of the vault beneficiary of the prize pool contributions
    /// @param _prizePool The prize pool the vault will contribute to
    /// @param _liquidationPairFactory The factory to use for creating liquidation pairs
    /// @param _targetAuctionPeriod The target auction period for liquidations
    /// @param _targetAuctionPrice The target auction price for liquidations
    /// @param _smoothingFactor The smoothing factor for liquidations
    /// @return AaveV3ERC4626Liquidator The newly deployed AaveV3ERC4626Liquidator
    function createLiquidator(
        address _creator,
        address _vaultBeneficiary,
        IPrizePool _prizePool,
        TpdaLiquidationPairFactory _liquidationPairFactory,
        uint256 _targetAuctionPeriod,
        uint192 _targetAuctionPrice,
        uint256 _smoothingFactor
    ) external returns (AaveV3ERC4626Liquidator) {
        AaveV3ERC4626Liquidator liquidator = new AaveV3ERC4626Liquidator{
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

        emit NewAaveV3ERC4626Liquidator(liquidator);

        return liquidator;
    }

    /// @notice Total number of liquidators deployed by this factory.
    /// @return uint256 Number of liquidators deployed by this factory.
    function totalLiquidators() external view returns (uint256) {
        return allLiquidators.length;
    }
}
