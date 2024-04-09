/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import {
    AaveV3ERC4626Liquidator,
    IPrizePool,
    TpdaLiquidationPairFactory
} from "../src/AaveV3ERC4626Liquidator.sol";

contract AaveV3ERC4626LiquidatorTest is Test {

    AaveV3ERC4626Liquidator liquidator;

    address creator = makeAddr("creator");
    address vaultBeneficiary = makeAddr("vaultBeneficiary");
    IPrizePool prizePool = IPrizePool(makeAddr("prizePool"));
    TpdaLiquidationPairFactory liquidationPairFactory = TpdaLiquidationPairFactory(makeAddr("liquidationPairFactory"));
    uint256 targetAuctionPeriod = 1 days;
    uint192 targetAuctionPrice = 0.001 ether;
    uint256 smoothingFactor = 0.9 ether;

    function setUp() public {
        liquidator = new AaveV3ERC4626Liquidator(
            creator,
            vaultBeneficiary,
            prizePool,
            liquidationPairFactory,
            targetAuctionPeriod,
            targetAuctionPrice,
            smoothingFactor
        );
    }

    function test_constructor() public {
        assertEq(liquidator.creator(), creator, "creator");
        assertEq(liquidator.vaultBeneficiary(), vaultBeneficiary, "vaultBeneficiary");
        assertEq(address(liquidator.prizePool()), address(prizePool), "prizePool");
        assertEq(address(liquidator.liquidationPairFactory()), address(liquidationPairFactory), "liquidationPairFactory");
        assertEq(liquidator.targetAuctionPeriod(), targetAuctionPeriod, "targetAuctionPeriod");
        assertEq(liquidator.targetAuctionPrice(), targetAuctionPrice, "targetAuctionPrice");
        assertEq(liquidator.smoothingFactor(), smoothingFactor, "smoothingFactor");
    }

    
}