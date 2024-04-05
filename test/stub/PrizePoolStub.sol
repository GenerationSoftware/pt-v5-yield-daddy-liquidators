/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import  { IERC20, IPrizePool } from "../../src/external/interfaces/IPrizePool.sol";

contract PrizePoolStub is IPrizePool {

    IERC20 public immutable prizeToken;

    mapping(address vault => uint256 contributed) public contributions;
    uint256 public totalContributed;

    constructor(IERC20 _prizeToken) {
        prizeToken = _prizeToken;
    }

    function contributePrizeTokens(address _prizeVault, uint256 _amount) external returns (uint256) {
        uint extra = prizeToken.balanceOf(address(this)) - totalContributed;
        require(extra >= _amount, "PrizePoolStub: Not enough tokens");
        totalContributed += _amount;
        contributions[_prizeVault] += _amount;
    }
}
