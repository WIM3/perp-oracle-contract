// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IUniswapV3PriceFeed {
    function getPrice() external view returns (uint256);

    function decimals() external pure returns (uint8);
}
