/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { TpdaLiquidationPairFactory } from "pt-v5-tpda-liquidator/TpdaLiquidationPairFactory.sol";
import {
    ERC20,
    IPool,
    IRewardsController,
    AaveV3ERC4626
} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

import { RewardLiquidator, TpdaLiquidationPair, IRewardSource } from "../../src/RewardLiquidator.sol";
import { IERC20, PrizePoolStub } from "../stub/PrizePoolStub.sol";

interface IRewardsControllerExt {
    function getRewardsByAsset(address _asset) external view returns (address[] memory);
}

contract AaveV3ERC4626RewardLiquidatorForkTest is Test {
    RewardLiquidator public liquidator;
    IERC20 public immutable weth = IERC20(0x4200000000000000000000000000000000000006);
    address vault = makeAddr("vault");
    TpdaLiquidationPairFactory factory;
    PrizePoolStub prizePool;
    AaveV3ERC4626 yieldVault;
    TpdaLiquidationPair pair;

    ERC20 public immutable USDC = ERC20(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
    ERC20 public immutable aUSDC = ERC20(0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5);
    IRewardsController public immutable REWARDS_CONTROLLER = IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e);
    IPool public immutable POOL = IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    address public immutable OP = 0x4200000000000000000000000000000000000042;

    uint256 public optimismFork;

    uint immutable usdcCreatedAtBlock   = 112788107;
    uint immutable startBlockNumber     = 118195000;
    uint immutable endBlockNumber       = 118262416;
    uint immutable startBlockTimestamp = 1711988777;
    uint immutable endBlockTimestamp = 1712123609;

    uint immutable opEmissionsEndedTimestamp = 1712173863;

    function setUp() public {
        optimismFork = vm.createFork(vm.rpcUrl("optimism"), startBlockNumber);
        vm.selectFork(optimismFork);

        prizePool = new PrizePoolStub(weth);
        factory = new TpdaLiquidationPairFactory();
        console2.log("created factory");
        liquidator = new RewardLiquidator(
            address(this),
            vault,
            prizePool,
            factory,
            6 hours,
            0.001 ether,
            0.5e18
        );
        console2.log("created liquidator");
        yieldVault = new AaveV3ERC4626(
            USDC,
            aUSDC,
            POOL,
            address(liquidator),
            REWARDS_CONTROLLER
        );
        console2.log("created yieldVault");
        liquidator.setYieldVault(IRewardSource(address(yieldVault)));

        deal(address(USDC), msg.sender, 1e18);
        deal(address(USDC), address(this), 1e18);
        deal(address(weth), address(this), 1e30);

        pair = liquidator.initializeRewardToken(OP);
        vm.warp(block.timestamp + 1 days);
    }

    function testDeposit() public {
        uint depositSize = yieldVault.maxDeposit(address(this)) / 2;
        USDC.approve(address(yieldVault), depositSize);
        yieldVault.deposit(depositSize, address(this));
        console2.log("Deposited %e", depositSize);

        address[] memory rewards = IRewardsControllerExt(address(REWARDS_CONTROLLER)).getRewardsByAsset(address(aUSDC));
        if (rewards.length > 0) {
            console2.log("REWARDS!", rewards.length);
        }

        uint totalOpOut;
        uint totalEthIn;

        uint deltaTime = 5 minutes;
        while (block.timestamp < opEmissionsEndedTimestamp) {
            uint balance = pair.maxAmountOut();
            if (balance > 0) {
                uint price = pair.computeExactAmountIn(1);
                // if exchange rate better than 1000 OP / ETH, then arb
                uint costInEth = balance / 1000;
                if (price < costInEth) {
                    totalOpOut += balance;
                    totalEthIn += price;
                    weth.transfer(address(prizePool), price);
                    pair.swapExactAmountOut(address(this),0,1e50,"");
                    uint efficiency = (price * 3000 * 1000) / (balance * 3);
                    console2.log("@ %s SWAPPED %e ETH for %e OP", block.timestamp, price, balance);
                    console2.log("\tefficiency: %s", efficiency);
                }
                
            }
            vm.warp(block.timestamp + deltaTime);   
        }

        uint totalEfficiency = (totalEthIn * 3000 * 1000) / (totalOpOut * 3);
        console2.log("Total OP out (usd): %e", totalOpOut * 3);
        console2.log("Total ETH in (usd): %e", totalEthIn * 3000);
        console2.log("Total efficiency: %s", totalEfficiency);
    }
}
