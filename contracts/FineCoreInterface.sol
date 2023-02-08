// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

interface FineCoreInterface {
    function getProjectAddress(uint id) external view returns (address);
    function getRandomness(uint id, uint256 seed) external view returns (uint randomnesss);
    function getTreasury() external view returns (address payable);
    function getPlatformPercentage() external view returns (uint);
    function getPlatformRoyalty() external view returns (uint);
}