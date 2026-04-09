// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

interface IERC20Minimal {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract ReadChainState is Script {
    function run() external view {
        address aavePool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        _readLatestBlockContext();
        _readAddressBalances(aavePool, usdc);
    }

    function _scale(uint8 decimals) internal pure returns (uint256) {
        return 10 ** uint256(decimals);
    }

    function _readLatestBlockContext() internal view {
        console2.log("=== Latest Block Context ===");
        console2.log("Block number:", block.number);
        console2.log("Timestamp:", block.timestamp);
        console2.log("Gas limit:", block.gaslimit);
        console2.log("Chain id:", block.chainid);
        console2.log("Base fee:", block.basefee);
    }

    function _readAddressBalances(address target, address token) internal view {
        uint256 ethBalanceWei = target.balance;

        IERC20Minimal erc20 = IERC20Minimal(token);
        uint256 tokenBalanceRaw = erc20.balanceOf(target);
        uint8 tokenDecimals = erc20.decimals();

        uint256 ethWhole = ethBalanceWei / 1e18;
        uint256 tokenWhole = tokenBalanceRaw / _scale(tokenDecimals);

        console2.log("=== Address Balance Context ===");
        console2.log("Target:", target);

        console2.log("ETH balance (wei):", ethBalanceWei);
        console2.log("ETH balance (whole units):", ethWhole);

        console2.log("Token:", token);
        console2.log("Token decimals:", uint256(tokenDecimals));
        console2.log("Token balance (raw):", tokenBalanceRaw);
        console2.log("Token balance (whole units):", tokenWhole);
    }
}
