// SPDX-License-Identifier: MIT License
pragma solidity 0.7.6;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import { IPriceFeed } from "./interface/IPriceFeed.sol";
import { BlockContext } from "./base/BlockContext.sol";

contract ChainlinkPriceFeed is IPriceFeed, BlockContext {
    using SafeMath for uint256;
    using Address for address;

    AggregatorV3Interface private immutable _aggregator;

    constructor(AggregatorV3Interface aggregator) {
        // CPF_ANC: Aggregator address is not contract
        require(address(aggregator).isContract(), "CPF_ANC");

        _aggregator = aggregator;
    }

    function decimals() external view override returns (uint8) {
        return _aggregator.decimals();
    }

    function getPrice(uint256 interval) external view override returns (uint256) {
        // 3 different timestamps, `previous`, `current`, `target`
        // `base` = now - _interval
        // `current` = current round timestamp from aggregator
        // `previous` = previous round timestamp form aggregator
        // now >= previous > current > = < base
        //
        //  while loop i = 0
        //  --+------+-----+-----+-----+-----+-----+
        //         base                 current  now(previous)
        //
        //  while loop i = 1
        //  --+------+-----+-----+-----+-----+-----+
        //         base           current previous now

        (uint80 round, uint256 latestPrice, uint256 latestTimestamp) = _getLatestRoundData();
        if (interval == 0 || round == 0) {
            return latestPrice;
        }

        uint256 baseTimestamp = _blockTimestamp().sub(interval);
        // if latest updated timestamp is earlier than target timestamp, return the latest price.
        if (latestTimestamp < baseTimestamp) {
            return latestPrice;
        }

        // rounds are like snapshots, latestRound means the latest price snapshot. follow chainlink naming
        uint256 previousTimestamp = latestTimestamp;
        uint256 cumulativeTime = _blockTimestamp().sub(previousTimestamp);
        uint256 weightedPrice = latestPrice.mul(cumulativeTime);
        uint256 timeFraction;
        while (true) {
            if (round == 0) {
                // To prevent from div 0 error, return the latest price if `cumulativeTime == 0`
                if (cumulativeTime == 0) {
                    return latestPrice;
                }
                // if cumulative time is less than requested interval, return current twap price
                return weightedPrice.div(cumulativeTime);
            }

            round = round - 1;
            (, uint256 currentPrice, uint256 currentTimestamp) = _getRoundData(round);

            // check if current round timestamp is earlier than target timestamp
            if (currentTimestamp <= baseTimestamp) {
                // weighted time period will be (target timestamp - previous timestamp). For example,
                // now is 1000, interval is 100, then target timestamp is 900. If timestamp of current round is 970,
                // and timestamp of NEXT round is 880, then the weighted time period will be (970 - 900) = 70,
                // instead of (970 - 880)
                weightedPrice = weightedPrice.add(currentPrice.mul(previousTimestamp.sub(baseTimestamp)));
                break;
            }

            timeFraction = previousTimestamp.sub(currentTimestamp);
            weightedPrice = weightedPrice.add(currentPrice.mul(timeFraction));
            cumulativeTime = cumulativeTime.add(timeFraction);
            previousTimestamp = currentTimestamp;
        }
        if (weightedPrice == 0) {
            return latestPrice;
        }
        return weightedPrice.div(interval);
    }

    function _getLatestRoundData()
        private
        view
        returns (
            uint80,
            uint256 finalPrice,
            uint256
        )
    {
        (uint80 round, int256 latestPrice, , uint256 latestTimestamp, ) = _aggregator.latestRoundData();
        finalPrice = uint256(latestPrice);
        if (latestPrice < 0) {
            _requireEnoughHistory(round);
            (round, finalPrice, latestTimestamp) = _getRoundData(round - 1);
        }
        return (round, finalPrice, latestTimestamp);
    }

    function _getRoundData(uint80 _round)
        private
        view
        returns (
            uint80,
            uint256,
            uint256
        )
    {
        (uint80 round, int256 latestPrice, , uint256 latestTimestamp, ) = _aggregator.getRoundData(_round);
        while (latestPrice < 0) {
            _requireEnoughHistory(round);
            round = round - 1;
            (, latestPrice, , latestTimestamp, ) = _aggregator.getRoundData(round);
        }
        return (round, uint256(latestPrice), latestTimestamp);
    }

    function _requireEnoughHistory(uint80 _round) private pure {
        // CPF_NEH: Not enough history
        require(_round > 0, "CPF_NEH");
    }
}
