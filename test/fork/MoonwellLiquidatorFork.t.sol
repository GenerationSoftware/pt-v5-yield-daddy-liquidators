/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import { TpdaLiquidationPairFactory } from "pt-v5-tpda-liquidator/TpdaLiquidationPairFactory.sol";

import { RewardLiquidator, TpdaLiquidationPair, IRewardSource } from "../../src/RewardLiquidator.sol";
import { IERC20, PrizePoolStub } from "../stub/PrizePoolStub.sol";

contract MoonwellRewardLiquidatorForkTest is Test {
    RewardLiquidator public liquidator;
    IERC20 public immutable weth = IERC20(0x4200000000000000000000000000000000000006);
    address vault = makeAddr("vault");
    TpdaLiquidationPairFactory factory;
    PrizePoolStub prizePool;
    IRewardSource yieldVault = IRewardSource(0x370E0EEEE6f4fa0cc1B818134186Cee6BcE4801d);
    TpdaLiquidationPair pair;

    IERC20 public immutable USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IERC20 public immutable mUSDC = IERC20(0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22);
    address public immutable WELL = address(0xA88594D404727625A9437C3f886C7643872296AE);

    uint256 public baseFork;

    uint immutable startBlockNumber = 14464905;
    uint immutable startBlockTimestamp = 1715719157;

    uint immutable endTimestamp = 1715919157;

    function setUp() public {
        baseFork = vm.createFork(vm.rpcUrl("base"), startBlockNumber);
        vm.selectFork(baseFork);
        vm.warp(startBlockTimestamp);

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

        // etch the liquidator code into the address of the yield vault reward recipient
        address rewardRecipient = yieldVault.rewardRecipient();
        vm.etch(rewardRecipient, address(liquidator).code);
        liquidator = RewardLiquidator(rewardRecipient);

        console2.log("created liquidator");

        liquidator.setYieldVault(yieldVault);

        deal(address(USDC), msg.sender, 1e18);
        deal(address(USDC), address(this), 1e18);
        deal(address(weth), address(this), 1e30);

        pair = liquidator.initializeRewardToken(WELL);
    }

    function testDeposit() public {
        uint depositSize = 10000e6;
        USDC.approve(address(yieldVault), depositSize);
        (bool deposited,) = address(yieldVault).call(abi.encodeWithSignature("deposit(uint256,address)", depositSize, address(this)));
        require(deposited, "failed to deposit");

        console2.log("Deposited %e", depositSize);

        uint totalWellOut;
        uint totalEthIn;

        uint deltaTime = 5 minutes;
        while (block.timestamp < endTimestamp) {
            uint balance = pair.maxAmountOut();
            if (balance > 0) {
                uint price = pair.computeExactAmountIn(1);
                // if exchange rate better than 107913 WELL / ETH, then arb
                uint costInEth = balance / 107913;
                if (price < costInEth) {
                    totalWellOut += balance;
                    totalEthIn += price;
                    weth.transfer(address(prizePool), price);
                    pair.swapExactAmountOut(address(this),0,1e50,"");
                    uint efficiency = (price * 3000 * 1000 * 1000) / (balance * 278);
                    console2.log("@ %s SWAPPED %e ETH for %e WELL", block.timestamp, price, balance);
                    console2.log("\tefficiency: %s", efficiency);
                }
                
            }
            vm.warp(block.timestamp + deltaTime);   
        }

        uint totalEfficiency = (totalEthIn * 3000 * 1000 * 1000) / (totalWellOut * 278);
        console2.log("Total WELL out (usd): %e", (totalWellOut * 278) / 1000);
        console2.log("Total ETH in (usd): %e", totalEthIn * 3000);
        console2.log("Total efficiency: %s", totalEfficiency);
    }
}
