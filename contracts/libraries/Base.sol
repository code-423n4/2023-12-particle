// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {FixedPoint128} from "../../lib/v3-core/contracts/libraries/FixedPoint128.sol";
import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";
import {Errors} from "./Errors.sol";
import {FullMath} from "./FullMath.sol";
import {TickMath} from "./TickMath.sol";
import {LiquidityAmounts} from "./LiquidityAmounts.sol";
import {DataStruct, DataCache} from "../libraries/Structs.sol";

/// @title Base Library
/// @notice Contains internal helper functions for all contracts
library Base {
    // solhint-disable private-vars-leading-underscore
    address internal constant UNI_POSITION_MANAGER_ADDR = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    uint256 internal constant BASIS_POINT = 1_000_000;

    INonfungiblePositionManager internal constant UNI_POSITION_MANAGER =
        INonfungiblePositionManager(UNI_POSITION_MANAGER_ADDR);
    IUniswapV3Factory internal constant UNI_FACTORY = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    // solhint-enable private-vars-leading-underscore

    /**
     * @notice Swap at most `amountFrom` of `tokenFrom` for at least `amountToMinimum` of `tokenTo`
     * @dev Caller must check for non-reentrancy and proper amount is deposited in
     * @param tokenFrom address of token to swap from
     * @param tokenTo address of token to swap to
     * @param amountFrom amount of tokenFrom to swap
     * @param amountToMinimum minimum amount of tokenTo to receive
     * @param dexAggregator address of DEX aggregator to perform swapping
     * @param data calldata bytes to pass into DEX aggregator to perform swapping
     * @return amountSpent amount of tokenFrom spent
     * @return amountReceived amount of tokenTo received
     */
    function swap(
        address tokenFrom,
        address tokenTo,
        uint256 amountFrom,
        uint256 amountToMinimum,
        address dexAggregator,
        bytes calldata data
    ) internal returns (uint256 amountSpent, uint256 amountReceived) {
        uint256 balanceFromBefore = IERC20(tokenFrom).balanceOf(address(this));
        uint256 balanceToBefore = IERC20(tokenTo).balanceOf(address(this));

        if (amountFrom > 0) {
            ///@dev only allow amountFrom of tokenFrom to be spent by the DEX aggregator
            TransferHelper.safeApprove(tokenFrom, dexAggregator, amountFrom);
            // solhint-disable-next-line avoid-low-level-calls
            (bool success, ) = dexAggregator.call(data);
            if (!success) revert Errors.SwapFailed();
            TransferHelper.safeApprove(tokenFrom, dexAggregator, 0);
        }

        amountSpent = balanceFromBefore - IERC20(tokenFrom).balanceOf(address(this));
        amountReceived = IERC20(tokenTo).balanceOf(address(this)) - balanceToBefore;

        if (amountReceived < amountToMinimum) revert Errors.InsufficientSwap();
    }

    /**
     * @notice Helper function to refund a token
     * @param recipient the address to receive the refund
     * @param token address of token to potentially refund
     * @param amountExpected amount of token0 expected to spend
     * @param amountActual amount of token0 actually spent
     */
    function refund(address recipient, address token, uint256 amountExpected, uint256 amountActual) internal {
        if (amountExpected > amountActual) {
            TransferHelper.safeTransfer(token, recipient, amountExpected - amountActual);
        }
    }

    /**
     * @notice Helper function to refund a token, with additional check that amountActual must not exceed amountExpected
     * @param recipient the address to receive the refund
     * @param token address of token to potentially refund
     * @param amountExpected amount of token0 expected to spend
     * @param amountActual amount of token0 actually spent
     */
    function refundWithCheck(address recipient, address token, uint256 amountExpected, uint256 amountActual) internal {
        if (amountActual > amountExpected) revert Errors.OverRefund();
        refund(recipient, token, amountExpected, amountActual);
    }

    /**
     * @notice Helper function to prepare data for leveraged swap
     * @param tokenId tokenId of the liquidity position NFT
     * @param liquidity amount of liquidity to borrow out
     * @param zeroForOne direction of the swap
     * @return tokenFrom token to swap from
     * @return tokenTo token to swap to
     * @return feeGrowthInside0LastX128 the current fee growth of the aggregate position for token0
     * @return feeGrowthInside1LastX128 the current fee growth of the aggregate position for token1
     * @return collateralFrom amount of `tokenFrom` that `liquidity` concentrates to at its end
     * @return collateralTo amount of `tokenTo` that `liquidity` concentrate to at its end
     */
    function prepareLeverage(
        uint256 tokenId,
        uint128 liquidity,
        bool zeroForOne
    )
        internal
        view
        returns (
            address tokenFrom,
            address tokenTo,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint256 collateralFrom,
            uint256 collateralTo
        )
    {
        int24 tickLower;
        int24 tickUpper;
        (
            ,
            ,
            tokenFrom,
            tokenTo,
            ,
            tickLower,
            tickUpper,
            ,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            ,

        ) = UNI_POSITION_MANAGER.positions(tokenId);

        (collateralFrom, collateralTo) = getRequiredCollateral(liquidity, tickLower, tickUpper);
        if (!zeroForOne) {
            (tokenFrom, tokenTo) = (tokenTo, tokenFrom);
            (collateralFrom, collateralTo) = (collateralTo, collateralFrom);
        }
    }

    /**
     * @notice Calculates the amount of collateral needed when borrowing liquidity from a position
     * @param liquidity amount of liquidity to borrow
     * @param tickLower lower tick of the position
     * @param tickUpper upper tick of the position
     * @return amount0 amount that the liquidity concentrates to at tickLower
     * @return amount1 amount that the liquidity concentrates to at tickHigher
     */
    function getRequiredCollateral(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
    }

    function getRequiredRepay(
        uint128 liquidity,
        uint256 tokenId
    ) internal view returns (uint256 amount0, uint256 amount1) {
        DataCache.RepayCache memory repayCache;
        (
            ,
            ,
            repayCache.token0,
            repayCache.token1,
            repayCache.fee,
            repayCache.tickLower,
            repayCache.tickUpper,
            ,
            ,
            ,
            ,

        ) = UNI_POSITION_MANAGER.positions(tokenId);
        IUniswapV3Pool pool = IUniswapV3Pool(UNI_FACTORY.getPool(repayCache.token0, repayCache.token1, repayCache.fee));
        (repayCache.sqrtRatioX96, , , , , , ) = pool.slot0();
        repayCache.sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(repayCache.tickLower);
        repayCache.sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(repayCache.tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            repayCache.sqrtRatioX96,
            repayCache.sqrtRatioAX96,
            repayCache.sqrtRatioBX96,
            liquidity
        );
    }

    /**
     * @notice Get the current owed fees for a position
     * @param params.tokenId tokenId of the liquidity position NFT
     * @param params.liquidity amount of liquidity in the position
     * @param params.feeGrowthInside0LastX128 the fee growth of the position for token0 as of the last fee update
     * @param params.feeGrowthInside1LastX128 the fee growth of the position for token1 as of the last fee update
     * @param params.token0PremiumPortion the portion of token0 premium locked in the lien
     * @param params.token1PremiumPortion the portion of token1 premium locked in the lien
     * @param zeroForOne direction of the swap
     * @return tokenFrom  address of token to swap from at close position
     * @return tokenTo address of token to swap to at close position
     * @return tokenFromOwed amount owed to the liquidity provider for the token on the side of swap from
     * @return tokenToOwed amount owed to the liquidity provider for the token on the side of swap to
     * @return tokenFromPremium amount of premium for the token on the side of swap from
     * @return tokenToPremium amount of premium for the token on the side of swap to
     * @return collateralFrom amount of collateral for the token on the side of swap from
     * @return collateralTo amount of collateral for the token on the side of swap to
     */
    function getOwedInfoConverted(
        DataStruct.OwedInfoParams memory params,
        bool zeroForOne
    )
        internal
        view
        returns (
            address tokenFrom,
            address tokenTo,
            uint128 tokenFromOwed,
            uint128 tokenToOwed,
            uint128 tokenFromPremium,
            uint128 tokenToPremium,
            uint256 collateralFrom,
            uint256 collateralTo
        )
    {
        (
            tokenFrom,
            tokenTo,
            tokenFromOwed,
            tokenToOwed,
            tokenFromPremium,
            tokenToPremium,
            collateralFrom,
            collateralTo
        ) = getOwedInfo(params);
        if (zeroForOne) {
            (tokenFrom, tokenTo) = (tokenTo, tokenFrom);
            (tokenFromOwed, tokenToOwed) = (tokenToOwed, tokenFromOwed);
            (tokenFromPremium, tokenToPremium) = (tokenToPremium, tokenFromPremium);
            (collateralFrom, collateralTo) = (collateralTo, collateralFrom);
        }
    }

    /**
     * @notice Get the current owed fees for a position
     * @param params.tokenId tokenId of the liquidity position NFT
     * @param params.liquidity amount of liquidity in the position
     * @param params.feeGrowthInside0LastX128 the fee growth of the position for token0 as of the last fee update
     * @param params.feeGrowthInside1LastX128 the fee growth of the position for token1 as of the last fee update
     * @param params.token0PremiumPortion the portion of token0 premium locked in the lien
     * @param params.token1PremiumPortion the portion of token1 premium locked in the lien
     * @return token0 address of token0
     * @return token1 address of token1
     * @return token0Owed amount of token0 owed to the liquidity provider
     * @return token1Owed amount of token1 owed to the liquidity provider
     * @return token0Premium amount of token0 premium locked in the lien
     * @return token1Premium amount of token1 premium locked in the lien
     * @return collateral0 amount of token0 required by the lp (if oneForZero)
     * @return collateral1 amount of token1 required by the lp (if zeroForOne)
     */
    function getOwedInfo(
        DataStruct.OwedInfoParams memory params
    )
        internal
        view
        returns (
            address token0,
            address token1,
            uint128 token0Owed,
            uint128 token1Owed,
            uint128 token0Premium,
            uint128 token1Premium,
            uint256 collateral0,
            uint256 collateral1
        )
    {
        DataCache.OwedInfoCache memory cache;
        (, , token0, token1, cache.fee, cache.tickLower, cache.tickUpper, , , , , ) = UNI_POSITION_MANAGER.positions(
            params.tokenId
        );
        (cache.feeGrowthInside0X128, cache.feeGrowthInside1X128) = getFeeGrowthInside(
            token0,
            token1,
            cache.fee,
            cache.tickLower,
            cache.tickUpper
        );
        (token0Owed, token1Owed) = getOwedFee(
            cache.feeGrowthInside0X128,
            cache.feeGrowthInside1X128,
            params.feeGrowthInside0LastX128,
            params.feeGrowthInside1LastX128,
            params.liquidity
        );
        (collateral0, collateral1) = getRequiredCollateral(params.liquidity, cache.tickLower, cache.tickUpper);
        (token0Premium, token1Premium) = getPremium(
            collateral0,
            collateral1,
            params.token0PremiumPortion,
            params.token1PremiumPortion
        );
    }

    /**
     * @notice Helper function to calculate the current feeGrothInside(0/1)X128 based on tickLower and tickUpper
     * @dev feeGrowthInsideX128 calculation adopted from uniswap v3 periphery PositionValue
     * @param token0 address of token0
     * @param token1 address of token1
     * @param fee fee level of the pool
     * @param tickLower lower tick of the position
     * @param tickUpper upper tick of the position
     * @return feeGrowthInside0X128 the current fee growth of the position for token0
     * @return feeGrowthInside1X128 the current fee growth of the position for token1
     */
    function getFeeGrowthInside(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        IUniswapV3Pool pool = IUniswapV3Pool(UNI_FACTORY.getPool(token0, token1, fee));
        (, int24 tickCurrent, , , , , ) = pool.slot0();
        (, , uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128, , , , ) = pool.ticks(tickLower);
        (, , uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128, , , , ) = pool.ticks(tickUpper);

        if (tickCurrent < tickLower) {
            feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
            feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
        } else if (tickCurrent < tickUpper) {
            uint256 feeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128();
            uint256 feeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128();
            feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
            feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
        } else {
            feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
            feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
        }
    }

    /**
     * @notice Helper function to get the fee owed based on the current and last feeGrowthInside
     * @param feeGrowthInside0X128 the current fee growth of the position for token0
     * @param feeGrowthInside1X128 the current fee growth of the position for token1
     * @param feeGrowthInside0LastX128 the fee growth of the position for token0 at the last borrow / fee collection
     * @param feeGrowthInside1LastX128 the fee growth of the position for token1 at the last borrow / fee collection
     * @param liquidity liquidity of the position
     * @return token0Owed amount of token0 owed
     * @return token1Owed amount of token1 owed
     */
    function getOwedFee(
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128,
        uint128 liquidity
    ) internal pure returns (uint128 token0Owed, uint128 token1Owed) {
        if (feeGrowthInside0X128 > feeGrowthInside0LastX128) {
            token0Owed = uint128(
                FullMath.mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128)
            );
        }
        if (feeGrowthInside1X128 > feeGrowthInside1LastX128) {
            token1Owed = uint128(
                FullMath.mulDiv(feeGrowthInside1X128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128)
            );
        }
    }

    /**
     * @notice Helper function to get the premium amount based on the premium portion and collateral as base
     * @param collateral0 the amount of collateral for token0
     * @param collateral1 the amount of collateral for token1
     * @param token0PremiumPortion the premium portion based on collateral0 and BASIS_POINT
     * @param token1PremiumPortion the premium portion based on collateral1 and BASIS_POINT
     * @return token0Premium amount of premium for token0
     * @return token1Premium amount of premium for token1
     */
    function getPremium(
        uint256 collateral0,
        uint256 collateral1,
        uint24 token0PremiumPortion,
        uint24 token1PremiumPortion
    ) internal pure returns (uint128 token0Premium, uint128 token1Premium) {
        token0Premium = uint128((token0PremiumPortion * collateral0) / BASIS_POINT);
        token1Premium = uint128((token1PremiumPortion * collateral1) / BASIS_POINT);
    }

    /**
     * @notice Helper function to fit a non-overflow uint256 value to uint24
     * @param value the uint256 value to fit
     * @return result uint24 value that fits
     */
    function uint256ToUint24(uint256 value) internal pure returns (uint24 result) {
        if (value > type(uint24).max) revert Errors.Overflow();
        result = uint24(value);
    }
}
