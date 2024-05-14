/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";

import {
    RewardLiquidator,
    IPrizePool,
    IRewardSource,
    TpdaLiquidationPair,
    TpdaLiquidationPairFactory,
    OnlyCreator,
    OnlyLiquidationPair,
    YieldVaultAlreadySet,
    InvalidRewardRecipient,
    AlreadyInitialized,
    CannotInitializeZeroAddress,
    UnknownRewardToken,
    IERC20
} from "../src/RewardLiquidator.sol";

contract RewardLiquidatorTest is Test {

    event YieldVaultSet(IRewardSource indexed yieldVault);
    event InitializedRewardToken(address indexed token, TpdaLiquidationPair indexed pair);

    RewardLiquidator liquidator;

    address vaultBeneficiary = makeAddr("vaultBeneficiary");
    IPrizePool prizePool = IPrizePool(makeAddr("prizePool"));
    IERC20 prizeToken = IERC20(makeAddr("prizeToken"));
    TpdaLiquidationPairFactory liquidationPairFactory = TpdaLiquidationPairFactory(makeAddr("liquidationPairFactory"));
    uint64 targetAuctionPeriod = 1 days;
    uint192 targetAuctionPrice = 0.001 ether;
    uint256 smoothingFactor = 0.9 ether;
    IRewardSource yieldVault = IRewardSource(makeAddr("IRewardSource"));
    address rewardToken = makeAddr("rewardToken");

    function setUp() public {
        vm.mockCall(address(prizePool), abi.encodeWithSelector(prizePool.prizeToken.selector), abi.encode(address(prizeToken)));
        liquidator = new RewardLiquidator(
            address(this),
            vaultBeneficiary,
            prizePool,
            liquidationPairFactory,
            targetAuctionPeriod,
            targetAuctionPrice,
            smoothingFactor
        );
    }

    function test_constructor() public {
        assertEq(liquidator.creator(), address(this), "creator");
        assertEq(liquidator.vaultBeneficiary(), vaultBeneficiary, "vaultBeneficiary");
        assertEq(address(liquidator.prizePool()), address(prizePool), "prizePool");
        assertEq(address(liquidator.liquidationPairFactory()), address(liquidationPairFactory), "liquidationPairFactory");
        assertEq(liquidator.targetAuctionPeriod(), targetAuctionPeriod, "targetAuctionPeriod");
        assertEq(liquidator.targetAuctionPrice(), targetAuctionPrice, "targetAuctionPrice");
        assertEq(liquidator.smoothingFactor(), smoothingFactor, "smoothingFactor");
    }

    function test_setYieldVault() public {
        setYieldVault();
        assertEq(address(liquidator.yieldVault()), address(yieldVault), "yieldVault");
    }

    function test_setYieldVault_OnlyCreator() public {
        vm.expectRevert(abi.encodeWithSelector(OnlyCreator.selector));
        vm.prank(makeAddr("fraud"));
        liquidator.setYieldVault(IRewardSource(makeAddr("IRewardSource")));
    }

    function test_setYieldVault_YieldVaultAlreadySet() public {
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(yieldVault.rewardRecipient.selector), abi.encode(address(liquidator)));
        liquidator.setYieldVault(yieldVault);

        vm.expectRevert(abi.encodeWithSelector(YieldVaultAlreadySet.selector));
        liquidator.setYieldVault(yieldVault);
    }

    function test_setYieldVault_InvalidRewardRecipient() public {
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(yieldVault.rewardRecipient.selector), abi.encode(address(this)));

        vm.expectRevert(abi.encodeWithSelector(InvalidRewardRecipient.selector));
        liquidator.setYieldVault(yieldVault);
    }

    function test_initializeRewardToken() public {
        TpdaLiquidationPair created = mockCreatePair();
        vm.expectEmit(true, true, true, true);
        emit InitializedRewardToken(rewardToken, created);
        TpdaLiquidationPair pair = liquidator.initializeRewardToken(rewardToken);
        assertEq(address(pair), address(created), "return value");
        assertEq(address(liquidator.liquidationPairs(rewardToken)), address(pair), "liquidationPairs[rewardToken]");
    }

    function test_initializeRewardToken_CannotInitializeZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(CannotInitializeZeroAddress.selector));
        liquidator.initializeRewardToken(address(0));
    }

    function test_initializeRewardToken_AlreadyInitialized() public {
        mockCreatePair();
        liquidator.initializeRewardToken(rewardToken);

        vm.expectRevert(abi.encodeWithSelector(AlreadyInitialized.selector));
        liquidator.initializeRewardToken(rewardToken);
    }

    function test_liquidatableBalanceOf() public {
        setYieldVault();
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(yieldVault.claimRewards.selector), abi.encode());
        vm.mockCall(address(prizeToken), abi.encodeWithSelector(prizeToken.balanceOf.selector, address(liquidator)), abi.encode(1000));
        assertEq(liquidator.liquidatableBalanceOf(address(prizeToken)), 1000, "liquidatableBalanceOf");
    }

    function test_transferTokensOut() public {  
        TpdaLiquidationPair pair = mockCreatePair();
        liquidator.initializeRewardToken(rewardToken);
        vm.prank(address(pair));

        address sender = makeAddr("sender");
        address receiver = makeAddr("receiver");
        uint256 amount = 1000;

        vm.mockCall(address(rewardToken), abi.encodeWithSelector(IERC20.transfer.selector, receiver, amount), abi.encode(true));
        liquidator.transferTokensOut(sender, receiver, rewardToken, amount);
    }
    
    function test_transferTokensOut_OnlyLiquidationPair() public {
        mockCreatePair();
        liquidator.initializeRewardToken(rewardToken);
        
        vm.prank(address(makeAddr("fraud")));
        vm.expectRevert(abi.encodeWithSelector(OnlyLiquidationPair.selector));
        liquidator.transferTokensOut(makeAddr("sender"), makeAddr("receiver"), rewardToken, 100e18);
    }

    function test_targetOf() public {
        assertEq(liquidator.targetOf(address(prizeToken)), address(prizePool), "targetOf");
    }

    function test_isLiquidationPair() public {
        TpdaLiquidationPair created = mockCreatePair();
        liquidator.initializeRewardToken(address(rewardToken));
        assertTrue(liquidator.isLiquidationPair(address(rewardToken), address(created)), "is pair");

        assertFalse(liquidator.isLiquidationPair(address(rewardToken), address(makeAddr("not pair"))), "not pair");
    }

    function test_isLiquidationPair_UnknownRewardToken() public {
        vm.expectRevert(abi.encodeWithSelector(UnknownRewardToken.selector));
        liquidator.isLiquidationPair(address(prizeToken), address(makeAddr("fake")));
    }

    function setYieldVault() public {
        vm.mockCall(address(yieldVault), abi.encodeWithSelector(yieldVault.rewardRecipient.selector), abi.encode(address(liquidator)));
        vm.expectEmit(true, true, true, true);
        emit YieldVaultSet(yieldVault);
        liquidator.setYieldVault(yieldVault);
    }

    function mockCreatePair() public returns (TpdaLiquidationPair) {
        TpdaLiquidationPair created = TpdaLiquidationPair(makeAddr("created"));
        vm.mockCall(
            address(liquidationPairFactory),
            abi.encodeWithSelector(liquidationPairFactory.createPair.selector,
                address(liquidator),
                address(prizePool.prizeToken()),
                rewardToken,
                targetAuctionPeriod,
                targetAuctionPrice,
                smoothingFactor
            ),
            abi.encode(address(created))
        );
        return created;
    }
}
