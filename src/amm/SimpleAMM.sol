// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract SimpleAMM {
    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public lastTimestamp;

    error ZeroAmount();
    error InsufficientLiquidity();
    error NotInitialized();

    event LiquidityInitialized(uint256 reserve0, uint256 reserve1);
    event Swap0For1(uint256 amount0In, uint256 amount1Out, uint256 amount0After, uint256 amount1After);
    event Swap1For0(uint256 amount1In, uint256 amount0Out, uint256 amount0After, uint256 amount1After);

    constructor(uint256 _reserve0, uint256 _reserve1) {
        if (_reserve0 == 0 || _reserve1 == 0) revert InsufficientLiquidity();

        reserve0 = _reserve0;
        reserve1 = _reserve1;
        lastTimestamp = uint32(block.timestamp);

        emit LiquidityInitialized(_reserve0, _reserve1);
    }

    function getSpotPrice0In1() public view returns (uint256) {
        if (reserve0 == 0 || reserve1 == 0) revert NotInitialized();
        return (reserve1 * 1e18) / reserve0;
    }

    function getSpotPrice1In0() public view returns (uint256) {
        if (reserve0 == 0 || reserve1 == 0) revert NotInitialized();
        return (reserve0 * 1e18) / reserve1;
    }

    function getInvariant() public view returns (uint256) {
        return reserve0 * reserve1;
    }

    function _updateCumulativePrices() internal {
        uint32 currentTimestamp = uint32(block.timestamp);
        uint32 timeElapsed = currentTimestamp - lastTimestamp;

        if (timeElapsed > 0 && reserve0 > 0 && reserve1 > 0) {
            uint256 price0 = getSpotPrice0In1();
            uint256 price1 = getSpotPrice1In0();

            price0CumulativeLast += price0 * timeElapsed;
            price1CumulativeLast += price1 * timeElapsed;
        }

        lastTimestamp = currentTimestamp;
    }

    function swap0For1(uint256 amount0In) external returns (uint256 amount1Out) {
        if (amount0In == 0) revert ZeroAmount();
        if (reserve0 == 0 || reserve1 == 0) revert InsufficientLiquidity();

        _updateCumulativePrices();

        uint256 k = reserve0 * reserve1;

        uint256 newReserve0 = reserve0 + amount0In;
        uint256 newReserve1 = k / newReserve0;

        amount1Out = reserve1 - newReserve1;

        if (amount1Out == 0 || newReserve1 == 0) revert InsufficientLiquidity();

        reserve0 = newReserve0;
        reserve1 = newReserve1;

        emit Swap0For1(amount0In, amount1Out, reserve0, reserve1);
    }

    function swap1For0(uint256 amount1In) external returns (uint256 amount0Out) {
        if (amount1In == 0) revert ZeroAmount();
        if (reserve1 == 0 || reserve0 == 0) revert InsufficientLiquidity();

        _updateCumulativePrices();

        uint256 k = reserve0 * reserve1;

        uint256 newReserve1 = reserve1 + amount1In;
        uint256 newReserve0 = k / newReserve1;

        amount0Out = reserve0 - newReserve0;

        if (amount0Out == 0 || newReserve0 == 0) revert InsufficientLiquidity();

        reserve0 = newReserve0;
        reserve1 = newReserve1;

        emit Swap1For0(amount1In, amount0Out, reserve0, reserve1);
    }
}
