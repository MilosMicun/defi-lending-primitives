// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "../../../src/oracle/interfaces/AggregatorV3Interface.sol";

contract MockOracle is AggregatorV3Interface {
    uint8 public override decimals;
    int256 private answer;
    uint256 private updatedAt;
    uint80 private roundId;
    uint80 private answeredInRound;

    constructor(uint8 decimals_, int256 answer_, uint256 updatedAt_) {
        decimals = decimals_;
        answer = answer_;
        updatedAt = updatedAt_;
        roundId = 1;
        answeredInRound = 1;
    }

    function description() external pure override returns (string memory) {
        return "Mock Oracle";
    }

    function setAnswer(int256 newAnswer) external {
        answer = newAnswer;
    }

    function setUpdatedAt(uint256 newUpdatedAt) external {
        updatedAt = newUpdatedAt;
    }

    function setRoundData(uint80 newRoundId, uint80 newAnsweredInRound) external {
        roundId = newRoundId;
        answeredInRound = newAnsweredInRound;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId_, int256 answer_, uint256 startedAt, uint256 updatedAt_, uint80 answeredInRound_)
    {
        return (roundId, answer, updatedAt, updatedAt, answeredInRound);
    }
}
