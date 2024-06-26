/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import {
    RewardLiquidatorFactory,
    RewardLiquidator,
    IPrizePool,
    TpdaLiquidationPairFactory
} from "../src/RewardLiquidatorFactory.sol";

contract RewardLiquidatorFactoryTest is Test {

    event NewRewardLiquidator(
        RewardLiquidator indexed liquidator
    );

    RewardLiquidatorFactory factory;

    address vaultBeneficiary = makeAddr("vaultBeneficiary");
    IPrizePool prizePool = IPrizePool(makeAddr("prizePool"));
    TpdaLiquidationPairFactory liquidationPairFactory = TpdaLiquidationPairFactory(makeAddr("liquidationPairFactory"));
    uint64 targetAuctionPeriod = 1 days;
    uint192 targetAuctionPrice = 0.001 ether;
    uint256 smoothingFactor = 0.9 ether;
    address rewardToken = makeAddr("rewardToken");
    address prizeToken = makeAddr("prizeToken");

    function setUp() public {
        factory = new RewardLiquidatorFactory();
        vm.mockCall(address(prizePool), abi.encodeWithSelector(prizePool.prizeToken.selector), abi.encode(address(prizeToken)));
    }

    function test_createLiquidator() public {
        vm.expectEmit(false, false, false, false);
        emit NewRewardLiquidator(RewardLiquidator(address(0)));
        RewardLiquidator liquidator = factory.createLiquidator(
            address(this),
            vaultBeneficiary,
            prizePool,
            liquidationPairFactory,
            targetAuctionPeriod,
            targetAuctionPrice,
            smoothingFactor
        );

        assertEq(liquidator.creator(), address(this));
        assertEq(liquidator.vaultBeneficiary(), vaultBeneficiary);
        assertEq(address(liquidator.prizePool()), address(prizePool));
        assertEq(address(liquidator.liquidationPairFactory()), address(liquidationPairFactory));
        assertEq(liquidator.targetAuctionPeriod(), targetAuctionPeriod);
        assertEq(liquidator.targetAuctionPrice(), targetAuctionPrice);
        assertEq(liquidator.smoothingFactor(), smoothingFactor);

        assertEq(factory.deployerNonces(address(this)), 1);
        assertEq(factory.totalLiquidators(), 1);
        assertEq(factory.deployedLiquidators(address(liquidator)), true);
    }

}
