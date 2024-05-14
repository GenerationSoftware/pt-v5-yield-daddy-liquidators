/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRewardSource {
    function rewardRecipient() external returns (address);
    function claimRewards() external;
}
