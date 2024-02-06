// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IPriceFeedUpdate {
    /// @dev Update latest price.
    function update() external;
}
