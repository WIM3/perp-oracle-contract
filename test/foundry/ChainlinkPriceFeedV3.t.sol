pragma solidity 0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Setup.sol";
import "../../contracts/interface/IPriceFeedV3.sol";
import "../../contracts/test/TestAggregatorV3.sol";

contract ChainlinkPriceFeedV3ConstructorTest is Setup {
    function test_CPF_ANC() public {
        vm.expectRevert(bytes("CPF_ANC"));
        _chainlinkPriceFeedV3 = new ChainlinkPriceFeedV3(
            TestAggregatorV3(0),
            _timeout,
            _maxOutlierDeviationRatio,
            _outlierCoolDownPeriod,
            _twapInterval
        );
    }

    function test_CPF_IMODR() public {
        vm.expectRevert(bytes("CPF_IMODR"));
        _chainlinkPriceFeedV3 = new ChainlinkPriceFeedV3(
            _testAggregator,
            _timeout,
            1e7,
            _outlierCoolDownPeriod,
            _twapInterval
        );
    }
}

contract ChainlinkPriceFeedV3Common is IPriceFeedV3Event, Setup {
    uint24 internal constant _ONE_HUNDRED_PERCENT_RATIO = 1e6;
    uint256 internal _timestamp = 10000000;
    uint256 internal _price = 1000 * 1e8;
    uint256 internal _roundId = 1;
    uint256 internal _timestampAfterOutlierCoolDownPeriod = _timestamp + _outlierCoolDownPeriod + 10;
    uint256 internal _timestampBeforeOutlierCoolDownPeriod = _timestamp + _outlierCoolDownPeriod - 5;

    function setUp() public virtual override {
        Setup.setUp();
        // we need Aggregator's decimals() function in the constructor of ChainlinkPriceFeedV3
        vm.mockCall(address(_testAggregator), abi.encodeWithSelector(_testAggregator.decimals.selector), abi.encode(8));
        _chainlinkPriceFeedV3 = _create_ChainlinkPriceFeedV3();

        vm.warp(_timestamp);
        _mock_call_latestRoundData(_roundId, int256(_price), _timestamp);
    }

    function _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(uint256 interval, uint256 price) internal {
        _chainlinkPriceFeedV3.cacheTwap(interval);
        assertEq(_chainlinkPriceFeedV3.getCachedTwap(interval), price);
    }

    function _chainlinkPriceFeedV3Broken_cacheTwap_and_assert_eq(uint256 interval, uint256 price) internal {
        _chainlinkPriceFeedV3Broken.cacheTwap(interval);
        assertEq(_chainlinkPriceFeedV3Broken.getCachedTwap(interval), price);
    }

    function _expect_revert_cacheTwap_CT_IT_with__twapInterval() internal {
        vm.expectRevert(bytes("CT_IT"));
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);
    }

    function _mock_call_latestRoundData(
        uint256 roundId,
        int256 answer,
        uint256 timestamp
    ) internal {
        vm.mockCall(
            address(_testAggregator),
            abi.encodeWithSelector(_testAggregator.latestRoundData.selector),
            abi.encode(roundId, answer, timestamp, timestamp, roundId)
        );
    }

    function _expect_emit_event_from_ChainlinkPriceFeedV3() internal {
        vm.expectEmit(false, false, false, true, address(_chainlinkPriceFeedV3));
    }
}

contract ChainlinkPriceFeedV3GetterTest is ChainlinkPriceFeedV3Common {
    function test_getAggregator() public {
        assertEq(_chainlinkPriceFeedV3.getAggregator(), address(_testAggregator));
    }

    function test_getLastValidPrice_is_0_when_initialized() public {
        assertEq(_chainlinkPriceFeedV3.getLastValidPrice(), 0);
    }

    function test_getLastValidTime_is_0_when_initialized() public {
        assertEq(_chainlinkPriceFeedV3.getLastValidTime(), 0);
    }

    function test_decimals() public {
        assertEq(uint256(_chainlinkPriceFeedV3.decimals()), uint256(_testAggregator.decimals()));
    }

    function test_isTimedOut_is_false_when_initialized() public {
        assertEq(_chainlinkPriceFeedV3.isTimedOut(), false);
    }

    function test_isTimedOut() public {
        vm.warp(_timeout - 1);
        assertEq(_chainlinkPriceFeedV3.isTimedOut(), true);
    }
}

contract ChainlinkPriceFeedV3IntervalIsZeroTest is ChainlinkPriceFeedV3Common {
    using SafeMath for uint256;

    function test_cacheTwap_first_time_caching_with_valid_price() public {
        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(_price, _timestamp, FreezedReason.NotFreezed);

        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(0, _price);
        assertEq(_chainlinkPriceFeedV3.getLastValidPrice(), _price);
        assertEq(_chainlinkPriceFeedV3.getLastValidTime(), _timestamp);
    }

    function test_getCachedTwap_with_valid_price_after_a_second() public {
        uint256 latestPrice = _price + 1e8;
        _chainlinkPriceFeedV3.cacheTwap(0);
        vm.warp(_timestamp + 1);
        _mock_call_latestRoundData(_roundId + 1, int256(latestPrice), _timestamp + 1);
        assertEq(_chainlinkPriceFeedV3.getCachedTwap(0), latestPrice);
    }

    function test_cacheTwap_wont_update_when_the_new_timestamp_is_the_same() public {
        _chainlinkPriceFeedV3.cacheTwap(0);

        // giving a different price but the same timestamp
        _mock_call_latestRoundData(_roundId, 2000 * 1e8, _timestamp);

        // price won't get updated; still the existing _lastValidPrice
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(0, _price);
    }

    function test_cacheTwap_freezedReason_is_NoResponse() public {
        // note that it's _chainlinkPriceFeedV3Broken here, not _chainlinkPriceFeedV3
        vm.expectEmit(false, false, false, true, address(_chainlinkPriceFeedV3Broken));
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.NoResponse);

        _chainlinkPriceFeedV3Broken_cacheTwap_and_assert_eq(0, 0);
        assertEq(_chainlinkPriceFeedV3Broken.getLastValidTime(), 0);
        assertEq(int256(_chainlinkPriceFeedV3Broken.getFreezedReason()), int256(FreezedReason.NoResponse));
    }

    function test_cacheTwap_freezedReason_is_IncorrectDecimals() public {
        vm.mockCall(address(_testAggregator), abi.encodeWithSelector(_testAggregator.decimals.selector), abi.encode(7));

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.IncorrectDecimals);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(0, 0);
    }

    function test_cacheTwap_freezedReason_is_NoRoundId() public {
        _mock_call_latestRoundData(0, int256(_price), _timestamp);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.NoRoundId);
        _chainlinkPriceFeedV3.cacheTwap(0);
    }

    function test_cacheTwap_freezedReason_is_InvalidTimestamp_with_zero_timestamp() public {
        // zero timestamp
        _mock_call_latestRoundData(_roundId, int256(_price), 0);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.InvalidTimestamp);
        _chainlinkPriceFeedV3.cacheTwap(0);
    }

    function test_cacheTwap_freezedReason_is_InvalidTimestamp_with_future_timestamp() public {
        // future
        _mock_call_latestRoundData(_roundId, int256(_price), _timestamp + 1);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.InvalidTimestamp);
        _chainlinkPriceFeedV3.cacheTwap(0);
    }

    function test_cacheTwap_freezedReason_is_InvalidTimestamp_with_past_timestamp() public {
        _chainlinkPriceFeedV3.cacheTwap(0);

        // < _lastValidTime
        _mock_call_latestRoundData(_roundId, int256(_price), _timestamp - 1);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(_price, _timestamp, FreezedReason.InvalidTimestamp);
        _chainlinkPriceFeedV3.cacheTwap(0);
    }

    function test_cacheTwap_freezedReason_is_NonPositiveAnswer() public {
        _mock_call_latestRoundData(_roundId, -1, _timestamp);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.NonPositiveAnswer);
        _chainlinkPriceFeedV3.cacheTwap(0);
    }

    function test_cacheTwap_freezedReason_is_AnswerIsOutlier_outlier_larger_than__lastValidPrice() public {
        _chainlinkPriceFeedV3.cacheTwap(0);

        int256 outlier = 2000 * 1e8;
        _mock_call_latestRoundData(_roundId + 1, outlier, _timestampAfterOutlierCoolDownPeriod);
        vm.warp(_timestampAfterOutlierCoolDownPeriod);

        uint256 maxDeviatedPrice =
            _price.mul(_ONE_HUNDRED_PERCENT_RATIO + _maxOutlierDeviationRatio).div(_ONE_HUNDRED_PERCENT_RATIO);
        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(
            maxDeviatedPrice,
            _timestampAfterOutlierCoolDownPeriod,
            FreezedReason.AnswerIsOutlier
        );
        _chainlinkPriceFeedV3.cacheTwap(0);
    }

    function test_cacheTwap_freezedReason_is_AnswerIsOutlier_outlier_smaller_than__lastValidPrice() public {
        _chainlinkPriceFeedV3.cacheTwap(0);

        int256 outlier = 500 * 1e8;
        _mock_call_latestRoundData(_roundId + 1, outlier, _timestampAfterOutlierCoolDownPeriod);
        vm.warp(_timestampAfterOutlierCoolDownPeriod);

        uint256 maxDeviatedPrice =
            _price.mul(_ONE_HUNDRED_PERCENT_RATIO - _maxOutlierDeviationRatio).div(_ONE_HUNDRED_PERCENT_RATIO);
        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(
            maxDeviatedPrice,
            _timestampAfterOutlierCoolDownPeriod,
            FreezedReason.AnswerIsOutlier
        );
        _chainlinkPriceFeedV3.cacheTwap(0);
    }

    function test_cacheTwap_freezedReason_is_AnswerIsOutlier_but_before__outlierCoolDownPeriod() public {
        _chainlinkPriceFeedV3.cacheTwap(0);

        _mock_call_latestRoundData(_roundId + 1, 500 * 1e8, _timestampBeforeOutlierCoolDownPeriod);
        vm.warp(_timestampBeforeOutlierCoolDownPeriod);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        // FreezedReason will be emitted while price & timestamp remain as _lastValidPrice & _lastValidTime
        emit ChainlinkPriceUpdated(_price, _timestamp, FreezedReason.AnswerIsOutlier);
        _chainlinkPriceFeedV3.cacheTwap(0);
    }

    function test_cacheTwap_no_outlier_but_timestamp_is_after__outlierCoolDownPeriod() public {
        _chainlinkPriceFeedV3.cacheTwap(0);

        int256 price = 950 * 1e8;
        _mock_call_latestRoundData(_roundId + 1, price, _timestampAfterOutlierCoolDownPeriod);
        vm.warp(_timestampAfterOutlierCoolDownPeriod);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(uint256(price), _timestampAfterOutlierCoolDownPeriod, FreezedReason.NotFreezed);
        _chainlinkPriceFeedV3.cacheTwap(0);
    }
}

contract ChainlinkPriceFeedV3IntervalIsNotZeroTest is ChainlinkPriceFeedV3Common {
    using SafeMath for uint256;

    function test_cacheTwap_first_time_caching_with_valid_price() public {
        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(_price, _timestamp, FreezedReason.NotFreezed);

        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, _price);
    }

    function test_getCachedTwap_first_time_without_cacheTwap_yet() public {
        assertEq(_chainlinkPriceFeedV3.getCachedTwap(_twapInterval), _price);
    }

    function test_getCachedTwap_with_valid_price_after_a_second() public {
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);
        vm.warp(_timestamp + 1);
        assertEq(_chainlinkPriceFeedV3.getCachedTwap(_twapInterval), _price);
    }

    function test_getCachedTwap_with_valid_price_after_several_seconds() public {
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);
        vm.warp(_timestamp + 1);
        _mock_call_latestRoundData(_roundId + 1, int256(_price + 1e8), _timestamp + 1);
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);
        vm.warp(_timestamp + 2);
        // (1000 * 1 + 1001 * 1) / 2 = 1000.5
        assertEq(_chainlinkPriceFeedV3.getCachedTwap(_twapInterval), 1000.5 * 1e8);
    }

    function test_getCachedTwap_with_valid_price_after_several_seconds_without_cacheTwap() public {
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);
        vm.warp(_timestamp + 2);
        _mock_call_latestRoundData(_roundId + 1, int256(_price + 1e8), _timestamp + 1);
        // (1000 * 1 + 1001 * 1) / 2 = 1000.5
        assertEq(_chainlinkPriceFeedV3.getCachedTwap(_twapInterval), 1000.5 * 1e8);
    }

    function test_cacheTwap_wont_update_when_the_new_timestamp_is_the_same() public {
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, _price);

        // giving a different price but the same old timestamp
        _mock_call_latestRoundData(_roundId, 2000 * 1e8, _timestamp);
        vm.warp(_timestamp + 1);

        // price won't get cached and tx will revert
        _expect_revert_cacheTwap_CT_IT_with__twapInterval();
    }

    function test_cacheTwap_freezedReason_is_NoResponse() public {
        // note that it's _chainlinkPriceFeedV3Broken here, not _chainlinkPriceFeedV3
        vm.expectEmit(false, false, false, true, address(_chainlinkPriceFeedV3Broken));
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.NoResponse);

        _chainlinkPriceFeedV3Broken_cacheTwap_and_assert_eq(_twapInterval, 0);
        assertEq(_chainlinkPriceFeedV3Broken.getLastValidTime(), 0);
        assertEq(int256(_chainlinkPriceFeedV3Broken.getFreezedReason()), int256(FreezedReason.NoResponse));
    }

    function test_cacheTwap_freezedReason_is_IncorrectDecimals() public {
        vm.mockCall(address(_testAggregator), abi.encodeWithSelector(_testAggregator.decimals.selector), abi.encode(7));

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.IncorrectDecimals);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 0);
    }

    function test_cacheTwap_freezedReason_is_NoRoundId() public {
        _mock_call_latestRoundData(0, int256(_price), _timestamp);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.NoRoundId);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 0);
    }

    function test_cacheTwap_freezedReason_is_InvalidTimestamp_with_zero_timestamp() public {
        // zero timestamp
        _mock_call_latestRoundData(_roundId, int256(_price), 0);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.InvalidTimestamp);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 0);
    }

    function test_cacheTwap_freezedReason_is_InvalidTimestamp_with_future_timestamp() public {
        // future
        _mock_call_latestRoundData(_roundId, int256(_price), _timestamp + 1);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.InvalidTimestamp);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 0);
    }

    function test_cacheTwap_freezedReason_is_InvalidTimestamp_with_past_timestamp() public {
        _chainlinkPriceFeedV3.cacheTwap(0);

        // < _lastValidTime
        _mock_call_latestRoundData(_roundId, int256(_price), _timestamp - 1);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(_price, _timestamp, FreezedReason.InvalidTimestamp);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, _price);
    }

    function test_cacheTwap_freezedReason_is_NonPositiveAnswer() public {
        _mock_call_latestRoundData(_roundId, -1, _timestamp);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(0, 0, FreezedReason.NonPositiveAnswer);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 0);
    }

    function test_cacheTwap_freezedReason_is_AnswerIsOutlier_outlier_larger_than__lastValidPrice() public {
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);

        int256 outlier = 2000 * 1e8;
        _mock_call_latestRoundData(_roundId + 1, outlier, _timestampAfterOutlierCoolDownPeriod);
        vm.warp(_timestampAfterOutlierCoolDownPeriod);

        uint256 maxDeviatedPrice =
            _price.mul(_ONE_HUNDRED_PERCENT_RATIO + _maxOutlierDeviationRatio).div(_ONE_HUNDRED_PERCENT_RATIO);
        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(
            maxDeviatedPrice,
            _timestampAfterOutlierCoolDownPeriod,
            FreezedReason.AnswerIsOutlier
        );
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, _price);
    }

    function test_cacheTwap_freezedReason_is_AnswerIsOutlier_outlier_smaller_than__lastValidPrice_twice() public {
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);

        int256 outlier = 500 * 1e8;
        _mock_call_latestRoundData(_roundId + 1, outlier, _timestampAfterOutlierCoolDownPeriod);
        vm.warp(_timestampAfterOutlierCoolDownPeriod);

        uint256 maxDeviatedPrice1 =
            _price.mul(_ONE_HUNDRED_PERCENT_RATIO - _maxOutlierDeviationRatio).div(_ONE_HUNDRED_PERCENT_RATIO);
        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(
            maxDeviatedPrice1,
            _timestampAfterOutlierCoolDownPeriod,
            FreezedReason.AnswerIsOutlier
        );
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, _price);

        uint256 timestampEvenAfter = _timestampAfterOutlierCoolDownPeriod + 15;
        _mock_call_latestRoundData(_roundId + 2, outlier, timestampEvenAfter);
        vm.warp(timestampEvenAfter);

        uint256 maxDeviatedPrice2 =
            maxDeviatedPrice1.mul(_ONE_HUNDRED_PERCENT_RATIO - _maxOutlierDeviationRatio).div(
                _ONE_HUNDRED_PERCENT_RATIO
            );
        emit ChainlinkPriceUpdated(maxDeviatedPrice2, timestampEvenAfter, FreezedReason.AnswerIsOutlier);
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);

        int256 randomPrice = int256(maxDeviatedPrice2);
        _mock_call_latestRoundData(_roundId + 3, randomPrice, _timestampAfterOutlierCoolDownPeriod + 20);
        vm.warp(_timestampAfterOutlierCoolDownPeriod + 20);

        // twap = (1000 * 20 + 900 (maxDeviatedPrice1) * 15 + 810 (maxDeviatedPrice2) * 5) / 40 = 938.75
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 93875 * 1e6);
    }

    function test_cacheTwap_freezedReason_is_AnswerIsOutlier_but_before__outlierCoolDownPeriod() public {
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);

        _mock_call_latestRoundData(_roundId + 1, 500 * 1e8, _timestampBeforeOutlierCoolDownPeriod);
        vm.warp(_timestampBeforeOutlierCoolDownPeriod);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        // FreezedReason will be emitted while price & timestamp remain as _lastValidPrice & _lastValidTime
        emit ChainlinkPriceUpdated(_price, _timestamp, FreezedReason.AnswerIsOutlier);
        // thus, cachedTwap didn't get updated and tx will revert
        _expect_revert_cacheTwap_CT_IT_with__twapInterval();
    }

    function test_cacheTwap_no_outlier_but_timestamp_is_after__outlierCoolDownPeriod() public {
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);

        int256 price = 950 * 1e8;
        _mock_call_latestRoundData(_roundId + 1, price, _timestampAfterOutlierCoolDownPeriod);
        vm.warp(_timestampAfterOutlierCoolDownPeriod);

        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(uint256(price), _timestampAfterOutlierCoolDownPeriod, FreezedReason.NotFreezed);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, _price);
    }
}

contract ChainlinkPriceFeedV3IntegrationTest is ChainlinkPriceFeedV3Common {
    using SafeMath for uint256;

    function test_integration_of_ChainlinkPriceFeedV3_CachedTwap_and_CumulativeTwap() public {
        _chainlinkPriceFeedV3.cacheTwap(_twapInterval);

        int256 price1 = 960 * 1e8;
        uint256 timestamp1 = _timestamp + 10;
        _mock_call_latestRoundData(_roundId + 1, price1, timestamp1);
        vm.warp(timestamp1);
        _expect_emit_event_from_ChainlinkPriceFeedV3();
        emit ChainlinkPriceUpdated(uint256(price1), timestamp1, FreezedReason.NotFreezed);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, _price);

        int256 price2 = 920 * 1e8;
        uint256 timestamp2 = timestamp1 + 20;
        _mock_call_latestRoundData(_roundId + 2, price2, timestamp2);
        vm.warp(timestamp2);
        // interval = 0 and thus twap won't get updated
        emit ChainlinkPriceUpdated(uint256(price1), timestamp1, FreezedReason.NotFreezed);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(0, uint256(price2));

        int256 price3 = 900 * 1e8;
        uint256 timestamp3 = timestamp2 + 20;
        _mock_call_latestRoundData(_roundId + 2, price3, timestamp3);
        vm.warp(timestamp3);
        // twap = (1000 * 10 + 960 * 40) / 50 = 968
        emit ChainlinkPriceUpdated(uint256(price3), timestamp3, FreezedReason.NotFreezed);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 968 * 1e8);

        int256 outlier1 = 500 * 1e8;
        uint256 timestamp4 = timestamp3 + _outlierCoolDownPeriod - 1;
        _mock_call_latestRoundData(_roundId + 3, outlier1, timestamp4);
        vm.warp(timestamp4);
        // hasn't passed _outlierCoolDownPeriod and thus both price & twap won't get updated
        emit ChainlinkPriceUpdated(uint256(price3), timestamp4, FreezedReason.AnswerIsOutlier);
        _expect_revert_cacheTwap_CT_IT_with__twapInterval();

        uint256 timestamp5 = timestamp3 + 50;
        // 900 * 0.9 = 810
        uint256 maxDeviatedPrice1 =
            uint256(price3).mul(_ONE_HUNDRED_PERCENT_RATIO - _maxOutlierDeviationRatio).div(_ONE_HUNDRED_PERCENT_RATIO);
        _mock_call_latestRoundData(_roundId + 4, outlier1, timestamp5);
        vm.warp(timestamp5);
        // twap = (1000 * 10 + 960 * 40 + 900 * 50) / 100 = 934
        emit ChainlinkPriceUpdated(maxDeviatedPrice1, timestamp5, FreezedReason.AnswerIsOutlier);
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 934 * 1e8);

        uint256 timestamp6 = timestamp5 - 1;
        vm.warp(timestamp6);
        emit ChainlinkPriceUpdated(maxDeviatedPrice1, timestamp5, FreezedReason.InvalidTimestamp);
        _expect_revert_cacheTwap_CT_IT_with__twapInterval();

        int256 price4 = 850 * 1e8;
        uint256 timestamp7 = timestamp5 + 100;
        _mock_call_latestRoundData(_roundId + 5, price4, timestamp7);
        vm.warp(timestamp7);
        emit ChainlinkPriceUpdated(uint256(price4), timestamp7, FreezedReason.NotFreezed);
        // twap = (1000 * 10 + 960 * 40 + 900 * 50 + 810 * 100) / 200 = 872
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 872 * 1e8);

        int256 outlier2 = 1500 * 1e8;
        uint256 timestamp8 = timestamp7 + 50;
        uint256 maxDeviatedPrice2 =
            uint256(price4).mul(_ONE_HUNDRED_PERCENT_RATIO + _maxOutlierDeviationRatio).div(_ONE_HUNDRED_PERCENT_RATIO);
        _mock_call_latestRoundData(_roundId + 6, outlier2, timestamp8);
        vm.warp(timestamp8);
        emit ChainlinkPriceUpdated(maxDeviatedPrice2, timestamp8, FreezedReason.AnswerIsOutlier);
        // twap = (1000 * 10 + 960 * 40 + 900 * 50 + 810 * 100 + 850 * 50) / 250 = 867.6
        _chainlinkPriceFeedV3_cacheTwap_and_assert_eq(_twapInterval, 8676 * 1e7);
    }
}
