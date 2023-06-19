// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IQuickswapV3 {
    function liquidity() external view returns (uint128);
    function globalState()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 fee,
            uint16 timepointIndex,
            uint8 communityFeeToken0,
            uint8 communityFeeToken1,
            bool unlocked
        );


}

contract BeefyReaderForTid2{

    // polygon network

    // ============ Hard Coded ============
    address public constant entrance = 0x7251FEbEABB01eC9dE53ECe7a96f1C951F886Dd2;

    // ============ Storage ============



    // -------------------------------
    // ------- User view functions -------
    // -------------------------------
    
    function getLiquidity(uint128 amountIn) external view returns(uint256 liquidity){
        
        if(amountIn == 0) return 0;
        
        // ouput -> native -> want
        
        // FBX -> WETH -> Wmatic
        uint wantAmount = getQuoteForUniV3(uint128(amountIn)); // uniswapV3
        
        // Wmatic -> quick
        liquidity = getQuoteForQuickV3(wantAmount); // quickswapV3
    }

    function getQuoteForUniV3(
        uint128 amountIn
    ) internal view returns (uint amountOut) {

        address tokenIn = 0xD125443F38A69d776177c2B9c041f462936F8218;  // FBX
        address tokenOut = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // WETH
        address pool = 0x6C14Fa1B23a245efb97CbaD357cA3948052d56Df;
        // Number of seconds in the past from which to calculate the time-weighted means
        uint32 secondsAgo = 60 * 5;
        amountIn = amountIn * uint128(997) / uint128(1000);

        (int24 tick, uint128 harmonicMeanLiquidity) = OracleLibrary.consult(pool, secondsAgo);
        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, tokenIn, tokenOut);
        amountIn = uint128(amountOut);

        tokenIn = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619; // WETH
        tokenOut = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // Wmatic
        pool = 0x167384319B41F7094e62f7506409Eb38079AbfF8;
        // amountIn = amountIn * uint128(997) / uint128(1000);

        (tick, harmonicMeanLiquidity) = OracleLibrary.consult(pool, secondsAgo);
        amountOut = OracleLibrary.getQuoteAtTick(tick, amountIn, tokenIn, tokenOut);
    }

    function getQuoteForQuickV3(
        uint256 amountIn
    ) internal view returns (uint amountOut) {
        IQuickswapV3 pool = IQuickswapV3(0x9F1A8cAF3C8e94e43aa64922d67dFf4dc3e88A42);
        
        (uint160 sqrtPriceX96, , uint16 fee, , , , ) = pool.globalState();
        uint128 liquidity = pool.liquidity();
        uint160 resultPrice = PriceMovementMath.getNewPriceAfterInput(sqrtPriceX96, liquidity, amountIn, true);
        
       (, uint256 input, uint256 ouput, uint256 feeAmount) 
            = PriceMovementMath.movePriceTowardsTarget(true, sqrtPriceX96, resultPrice, liquidity, int256(amountIn), fee);

        amountOut = ouput;
        
    }
}


/// @title Oracle library
/// @notice Provides functions to integrate with V3 pool oracle
library OracleLibrary {
    /// @notice Calculates time-weighted means of tick and liquidity for a given Uniswap V3 pool
    /// @param pool Address of the pool that we want to observe
    /// @param secondsAgo Number of seconds in the past from which to calculate the time-weighted means
    /// @return arithmeticMeanTick The arithmetic mean tick from (block.timestamp - secondsAgo) to block.timestamp
    /// @return harmonicMeanLiquidity The harmonic mean liquidity from (block.timestamp - secondsAgo) to block.timestamp
    function consult(address pool, uint32 secondsAgo)
        internal
        view
        returns (int24 arithmeticMeanTick, uint128 harmonicMeanLiquidity)
    {
        require(secondsAgo != 0, 'BP');

        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0;

        (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) =
            IUniswapV3Pool(pool).observe(secondsAgos);

        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        uint160 secondsPerLiquidityCumulativesDelta =
            secondsPerLiquidityCumulativeX128s[1] - secondsPerLiquidityCumulativeX128s[0];

        // arithmeticMeanTick = int24(tickCumulativesDelta / secondsAgo);
        arithmeticMeanTick = int24( tickCumulativesDelta / int56(int32(secondsAgo)) );
        // Always round to negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(int32(secondsAgo)) != 0)) arithmeticMeanTick--;

        // We are multiplying here instead of shifting to ensure that harmonicMeanLiquidity doesn't overflow uint128
        uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
        harmonicMeanLiquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
    }

    /// @notice Given a tick and a token amount, calculates the amount of token received in exchange
    /// @param tick Tick value used to calculate the quote
    /// @param baseAmount Amount of token to be converted
    /// @param baseToken Address of an ERC20 token contract used as the baseAmount denomination
    /// @param quoteToken Address of an ERC20 token contract used as the quoteAmount denomination
    /// @return quoteAmount Amount of quoteToken received for baseAmount of baseToken
    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) internal pure returns (uint256 quoteAmount) {
        uint160 sqrtRatioX96 = TickMath.getSqrtRatioAtTick(tick);

        // Calculate quoteAmount with better precision if it doesn't overflow when multiplied by itself
        if (sqrtRatioX96 <= type(uint128).max) {
            uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX192, baseAmount, 1 << 192)
                : FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        } else {
            uint256 ratioX128 = FullMath.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);
            quoteAmount = baseToken < quoteToken
                ? FullMath.mulDiv(ratioX128, baseAmount, 1 << 128)
                : FullMath.mulDiv(1 << 128, baseAmount, ratioX128);
        }
    }
}

interface IUniswapV3Pool {
    /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
    /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
    /// you must call it with secondsAgos = [3600, 0].
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
    /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
    /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
    /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
    /// timestamp
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
}

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
        require(absTick <= uint256(uint24(MAX_TICK)), 'T');

        uint256 ratio = absTick & 0x1 != 0 ? 0xfffcb933bd6fad37aa2d162d1a594001 : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
        if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
        if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
        if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
        if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
        if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
        if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
        if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
        if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
        if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
        if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
        if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
        if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
        if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
        if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
        if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
        if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
        if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
        if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

        if (tick > 0) ratio = type(uint256).max / ratio;

        // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
        // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
        // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
        sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
    }
}

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = a * b
            // Compute the product mod 2**256 and mod 2**256 - 1
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2**256 + prod0
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division
            if (prod1 == 0) {
                require(denominator > 0);
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            // Make sure the result is less than 2**256.
            // Also prevents denominator == 0
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0]
            // Compute remainder using mulmod
            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }
            // Subtract 256 bit number from 512 bit number
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            // Compute largest power of two divisor of denominator.
            // Always >= 1.
            uint256 twos = (0 - denominator) & denominator;
            // Divide denominator by power of two
            assembly {
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by the factors of two
            assembly {
                prod0 := div(prod0, twos)
            }
            // Shift in bits from prod1 into prod0. For this we need
            // to flip `twos` such that it is 2**256 / twos.
            // If twos is zero, then it becomes one
            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256
            // Now that denominator is an odd number, it has an inverse
            // modulo 2**256 such that denominator * inv = 1 mod 2**256.
            // Compute the inverse by starting with a seed that is correct
            // correct for four bits. That is, denominator * inv = 1 mod 2**4
            uint256 inv = (3 * denominator) ^ 2;
            // Now use Newton-Raphson iteration to improve the precision.
            // Thanks to Hensel's lifting lemma, this also works in modular
            // arithmetic, doubling the correct bits in each step.
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            // Because the division is now exact we can divide by multiplying
            // with the modular inverse of denominator. This will give us the
            // correct result modulo 2**256. Since the precoditions guarantee
            // that the outcome is less than 2**256, this is the final result.
            // We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inv;
            return result;
        }
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            result = mulDiv(a, b, denominator);
            if (mulmod(a, b, denominator) > 0) {
                require(result < type(uint256).max);
                result++;
            }
        }
    }

    /// @notice Returns ceil(x / y)
    /// @dev division by 0 has unspecified behavior, and must be checked externally
    /// @param x The dividend
    /// @param y The divisor
    /// @return z The quotient, ceil(x / y)
    function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
        z := add(div(x, y), gt(mod(x, y), 0))
        }
    }
}

/// @title Computes the result of price movement
/// @notice Contains methods for computing the result of price movement within a single tick price range.
library PriceMovementMath {

  using LowGasSafeMath for uint256;
  using SafeCast for uint256;

  /// @notice Gets the next sqrt price given an input amount of token0 or token1
  /// @dev Throws if price or liquidity are 0, or if the next price is out of bounds
  /// @param price The starting Q64.96 sqrt price, i.e., before accounting for the input amount
  /// @param liquidity The amount of usable liquidity
  /// @param input How much of token0, or token1, is being swapped in
  /// @param zeroToOne Whether the amount in is token0 or token1
  /// @return resultPrice The Q64.96 sqrt price after adding the input amount to token0 or token1
  function getNewPriceAfterInput(
    uint160 price,
    uint128 liquidity,
    uint256 input,
    bool zeroToOne
  ) internal pure returns (uint160 resultPrice) {
    return getNewPrice(price, liquidity, input, zeroToOne, true);
  }

  /// @notice Gets the next sqrt price given an output amount of token0 or token1
  /// @dev Throws if price or liquidity are 0 or the next price is out of bounds
  /// @param price The starting Q64.96 sqrt price before accounting for the output amount
  /// @param liquidity The amount of usable liquidity
  /// @param output How much of token0, or token1, is being swapped out
  /// @param zeroToOne Whether the amount out is token0 or token1
  /// @return resultPrice The Q64.96 sqrt price after removing the output amount of token0 or token1
  function getNewPriceAfterOutput(
    uint160 price,
    uint128 liquidity,
    uint256 output,
    bool zeroToOne
  ) internal pure returns (uint160 resultPrice) {
    return getNewPrice(price, liquidity, output, zeroToOne, false);
  }

  function getNewPrice(
    uint160 price,
    uint128 liquidity,
    uint256 amount,
    bool zeroToOne,
    bool fromInput
  ) internal pure returns (uint160 resultPrice) {
    require(price > 0);
    require(liquidity > 0);

    if (zeroToOne == fromInput) {
      // rounding up or down
      if (amount == 0) return price;
      uint256 liquidityShifted = uint256(liquidity) << Constants.RESOLUTION;

      if (fromInput) {
        uint256 product;
        if ((product = amount * price) / amount == price) {
          uint256 denominator = liquidityShifted + product;
          if (denominator >= liquidityShifted) return uint160(FullMath.mulDivRoundingUp(liquidityShifted, price, denominator)); // always fits in 160 bits
        }

        return uint160(FullMath.divRoundingUp(liquidityShifted, (liquidityShifted / price) + (amount)));
      } else {
        uint256 product;
        require((product = amount * price) / amount == price); // if the product overflows, we know the denominator underflows
        require(liquidityShifted > product); // in addition, we must check that the denominator does not underflow
        return FullMath.mulDivRoundingUp(liquidityShifted, price, liquidityShifted - product).toUint160();
      }
    } else {
      // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
      // in both cases, avoid a mulDiv for most inputs
      if (fromInput) {
        return
          uint256(price)
            .add(amount <= type(uint160).max ? (amount << Constants.RESOLUTION) / liquidity : FullMath.mulDiv(amount, Constants.Q96, liquidity))
            .toUint160();
      } else {
        uint256 quotient = amount <= type(uint160).max
          ? FullMath.divRoundingUp(amount << Constants.RESOLUTION, liquidity)
          : FullMath.mulDivRoundingUp(amount, Constants.Q96, liquidity);

        require(price > quotient);
        return uint160(price - quotient); // always fits 160 bits
      }
    }
  }

  function getTokenADelta01(
    uint160 to,
    uint160 from,
    uint128 liquidity
  ) internal pure returns (uint256) {
    return TokenDeltaMath.getToken0Delta(to, from, liquidity, true);
  }

  function getTokenADelta10(
    uint160 to,
    uint160 from,
    uint128 liquidity
  ) internal pure returns (uint256) {
    return TokenDeltaMath.getToken1Delta(from, to, liquidity, true);
  }

  function getTokenBDelta01(
    uint160 to,
    uint160 from,
    uint128 liquidity
  ) internal pure returns (uint256) {
    return TokenDeltaMath.getToken1Delta(to, from, liquidity, false);
  }

  function getTokenBDelta10(
    uint160 to,
    uint160 from,
    uint128 liquidity
  ) internal pure returns (uint256) {
    return TokenDeltaMath.getToken0Delta(from, to, liquidity, false);
  }

  /// @notice Computes the result of swapping some amount in, or amount out, given the parameters of the swap
  /// @dev The fee, plus the amount in, will never exceed the amount remaining if the swap's `amountSpecified` is positive
  /// @param currentPrice The current Q64.96 sqrt price of the pool
  /// @param targetPrice The Q64.96 sqrt price that cannot be exceeded, from which the direction of the swap is inferred
  /// @param liquidity The usable liquidity
  /// @param amountAvailable How much input or output amount is remaining to be swapped in/out
  /// @param fee The fee taken from the input amount, expressed in hundredths of a bip
  /// @return resultPrice The Q64.96 sqrt price after swapping the amount in/out, not to exceed the price target
  /// @return input The amount to be swapped in, of either token0 or token1, based on the direction of the swap
  /// @return output The amount to be received, of either token0 or token1, based on the direction of the swap
  /// @return feeAmount The amount of input that will be taken as a fee
  function movePriceTowardsTarget(
    bool zeroToOne,
    uint160 currentPrice,
    uint160 targetPrice,
    uint128 liquidity,
    int256 amountAvailable,
    uint16 fee
  )
    internal
    pure
    returns (
      uint160 resultPrice,
      uint256 input,
      uint256 output,
      uint256 feeAmount
    )
  {
    function(uint160, uint160, uint128) pure returns (uint256) getAmountA = zeroToOne ? getTokenADelta01 : getTokenADelta10;

    if (amountAvailable >= 0) {
      // exactIn or not
      uint256 amountAvailableAfterFee = FullMath.mulDiv(uint256(amountAvailable), 1e6 - fee, 1e6);
      input = getAmountA(targetPrice, currentPrice, liquidity);
      if (amountAvailableAfterFee >= input) {
        resultPrice = targetPrice;
        feeAmount = FullMath.mulDivRoundingUp(input, fee, 1e6 - fee);
      } else {
        resultPrice = getNewPriceAfterInput(currentPrice, liquidity, amountAvailableAfterFee, zeroToOne);
        if (targetPrice != resultPrice) {
          input = getAmountA(resultPrice, currentPrice, liquidity);

          // we didn't reach the target, so take the remainder of the maximum input as fee
          feeAmount = uint256(amountAvailable) - input;
        } else {
          feeAmount = FullMath.mulDivRoundingUp(input, fee, 1e6 - fee);
        }
      }

      output = (zeroToOne ? getTokenBDelta01 : getTokenBDelta10)(resultPrice, currentPrice, liquidity);
    } else {
      function(uint160, uint160, uint128) pure returns (uint256) getAmountB = zeroToOne ? getTokenBDelta01 : getTokenBDelta10;

      output = getAmountB(targetPrice, currentPrice, liquidity);
      amountAvailable = -amountAvailable;
      if (uint256(amountAvailable) >= output) resultPrice = targetPrice;
      else {
        resultPrice = getNewPriceAfterOutput(currentPrice, liquidity, uint256(amountAvailable), zeroToOne);

        if (targetPrice != resultPrice) {
          output = getAmountB(resultPrice, currentPrice, liquidity);
        }

        // cap the output amount to not exceed the remaining output amount
        if (output > uint256(amountAvailable)) {
          output = uint256(amountAvailable);
        }
      }

      input = getAmountA(resultPrice, currentPrice, liquidity);
      feeAmount = FullMath.mulDivRoundingUp(input, fee, 1e6 - fee);
    }
  }
}

library Constants {
  uint8 internal constant RESOLUTION = 96;
  uint256 internal constant Q96 = 0x1000000000000000000000000;
  uint256 internal constant Q128 = 0x100000000000000000000000000000000;
  // fee value in hundredths of a bip, i.e. 1e-6
  uint16 internal constant BASE_FEE = 100;
  int24 internal constant TICK_SPACING = 60;

  // max(uint128) / ( (MAX_TICK - MIN_TICK) / TICK_SPACING )
  uint128 internal constant MAX_LIQUIDITY_PER_TICK = 11505743598341114571880798222544994;

  uint32 internal constant MAX_LIQUIDITY_COOLDOWN = 1 days;
  uint8 internal constant MAX_COMMUNITY_FEE = 250;
  uint256 internal constant COMMUNITY_FEE_DENOMINATOR = 1000;
}



/// @title Functions based on Q64.96 sqrt price and liquidity
/// @notice Contains the math that uses square root of price as a Q64.96 and liquidity to compute deltas
library TokenDeltaMath {
  using LowGasSafeMath for uint256;
  using SafeCast for uint256;

  /// @notice Gets the token0 delta between two prices
  /// @dev Calculates liquidity / sqrt(lower) - liquidity / sqrt(upper)
  /// @param priceLower A Q64.96 sqrt price
  /// @param priceUpper Another Q64.96 sqrt price
  /// @param liquidity The amount of usable liquidity
  /// @param roundUp Whether to round the amount up or down
  /// @return token0Delta Amount of token0 required to cover a position of size liquidity between the two passed prices
  function getToken0Delta(
    uint160 priceLower,
    uint160 priceUpper,
    uint128 liquidity,
    bool roundUp
  ) internal pure returns (uint256 token0Delta) {
    uint256 priceDelta = priceUpper - priceLower;
    require(priceDelta < priceUpper); // forbids underflow and 0 priceLower
    uint256 liquidityShifted = uint256(liquidity) << Constants.RESOLUTION;

    token0Delta = roundUp
      ? FullMath.divRoundingUp(FullMath.mulDivRoundingUp(priceDelta, liquidityShifted, priceUpper), priceLower)
      : FullMath.mulDiv(priceDelta, liquidityShifted, priceUpper) / priceLower;
  }

  /// @notice Gets the token1 delta between two prices
  /// @dev Calculates liquidity * (sqrt(upper) - sqrt(lower))
  /// @param priceLower A Q64.96 sqrt price
  /// @param priceUpper Another Q64.96 sqrt price
  /// @param liquidity The amount of usable liquidity
  /// @param roundUp Whether to round the amount up, or down
  /// @return token1Delta Amount of token1 required to cover a position of size liquidity between the two passed prices
  function getToken1Delta(
    uint160 priceLower,
    uint160 priceUpper,
    uint128 liquidity,
    bool roundUp
  ) internal pure returns (uint256 token1Delta) {
    require(priceUpper >= priceLower);
    uint256 priceDelta = priceUpper - priceLower;
    token1Delta = roundUp ? FullMath.mulDivRoundingUp(priceDelta, liquidity, Constants.Q96) : FullMath.mulDiv(priceDelta, liquidity, Constants.Q96);
  }

  /// @notice Helper that gets signed token0 delta
  /// @param priceLower A Q64.96 sqrt price
  /// @param priceUpper Another Q64.96 sqrt price
  /// @param liquidity The change in liquidity for which to compute the token0 delta
  /// @return token0Delta Amount of token0 corresponding to the passed liquidityDelta between the two prices
  function getToken0Delta(
    uint160 priceLower,
    uint160 priceUpper,
    int128 liquidity
  ) internal pure returns (int256 token0Delta) {
    token0Delta = liquidity >= 0
      ? getToken0Delta(priceLower, priceUpper, uint128(liquidity), true).toInt256()
      : -getToken0Delta(priceLower, priceUpper, uint128(-liquidity), false).toInt256();
  }

  /// @notice Helper that gets signed token1 delta
  /// @param priceLower A Q64.96 sqrt price
  /// @param priceUpper Another Q64.96 sqrt price
  /// @param liquidity The change in liquidity for which to compute the token1 delta
  /// @return token1Delta Amount of token1 corresponding to the passed liquidityDelta between the two prices
  function getToken1Delta(
    uint160 priceLower,
    uint160 priceUpper,
    int128 liquidity
  ) internal pure returns (int256 token1Delta) {
    token1Delta = liquidity >= 0
      ? getToken1Delta(priceLower, priceUpper, uint128(liquidity), true).toInt256()
      : -getToken1Delta(priceLower, priceUpper, uint128(-liquidity), false).toInt256();
  }
}



/// @title Optimized overflow and underflow safe math operations
/// @notice Contains methods for doing math operations that revert on overflow or underflow for minimal gas cost
/// @dev Credit to Uniswap Labs under GPL-2.0-or-later license:
/// https://github.com/Uniswap/v3-core/blob/main/contracts/libraries
library LowGasSafeMath {
  /// @notice Returns x + y, reverts if sum overflows uint256
  /// @param x The augend
  /// @param y The addend
  /// @return z The sum of x and y
  function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x + y) >= x);
  }

  /// @notice Returns x - y, reverts if underflows
  /// @param x The minuend
  /// @param y The subtrahend
  /// @return z The difference of x and y
  function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x - y) <= x);
  }

  /// @notice Returns x * y, reverts if overflows
  /// @param x The multiplicand
  /// @param y The multiplier
  /// @return z The product of x and y
  function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(x == 0 || (z = x * y) / x == y);
  }

  /// @notice Returns x + y, reverts if overflows or underflows
  /// @param x The augend
  /// @param y The addend
  /// @return z The sum of x and y
  function add(int256 x, int256 y) internal pure returns (int256 z) {
    require((z = x + y) >= x == (y >= 0));
  }

  /// @notice Returns x - y, reverts if overflows or underflows
  /// @param x The minuend
  /// @param y The subtrahend
  /// @return z The difference of x and y
  function sub(int256 x, int256 y) internal pure returns (int256 z) {
    require((z = x - y) <= x == (y >= 0));
  }

  /// @notice Returns x + y, reverts if overflows or underflows
  /// @param x The augend
  /// @param y The addend
  /// @return z The sum of x and y
  function add128(uint128 x, uint128 y) internal pure returns (uint128 z) {
    require((z = x + y) >= x);
  }
}

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
/// @dev Credit to Uniswap Labs under GPL-2.0-or-later license:
/// https://github.com/Uniswap/v3-core/blob/main/contracts/libraries
library SafeCast {
  /// @notice Cast a uint256 to a uint160, revert on overflow
  /// @param y The uint256 to be downcasted
  /// @return z The downcasted integer, now type uint160
  function toUint160(uint256 y) internal pure returns (uint160 z) {
    require((z = uint160(y)) == y);
  }

  /// @notice Cast a int256 to a int128, revert on overflow or underflow
  /// @param y The int256 to be downcasted
  /// @return z The downcasted integer, now type int128
  function toInt128(int256 y) internal pure returns (int128 z) {
    require((z = int128(y)) == y);
  }

  /// @notice Cast a uint256 to a int256, revert on overflow
  /// @param y The uint256 to be casted
  /// @return z The casted integer, now type int256
  function toInt256(uint256 y) internal pure returns (int256 z) {
    require(y < 2**255);
    z = int256(y);
  }
}