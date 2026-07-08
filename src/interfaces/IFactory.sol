// SPDX-License-Identifier: MIT

pragma solidity 0.8.35;

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}