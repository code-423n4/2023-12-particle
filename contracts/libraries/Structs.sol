// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

// structs to pass in between functions
library DataStruct {
    struct OpenPositionParams {
        uint256 tokenId;
        uint256 marginFrom;
        uint256 marginTo;
        uint256 amountSwap;
        uint128 liquidity;
        uint24 tokenFromPremiumPortionMin;
        uint24 tokenToPremiumPortionMin;
        uint8 marginPremiumRatio;
        bool zeroForOne;
        bytes data;
    }

    struct ClosePositionParams {
        uint96 lienId;
        uint256 amountSwap;
        bytes data;
    }

    struct OwedInfoParams {
        uint40 tokenId;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint24 token0PremiumPortion;
        uint24 token1PremiumPortion;
    }

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0ToMint;
        uint256 amount1ToMint;
        uint256 amount0Min;
        uint256 amount1Min;
    }
}

// structs to use locally within functions
library DataCache {
    struct OpenPositionCache {
        address tokenFrom;
        address tokenTo;
        uint256 amountFromBorrowed;
        uint256 amountToBorrowed;
        uint256 amountSpent;
        uint256 amountReceived;
        uint256 collateralFrom; ///@dev collateralTo is the position amount in the returns
        uint24 token0PremiumPortion;
        uint24 token1PremiumPortion;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint256 feeAmount;
        uint256 treasuryAmount;
    }

    struct ClosePositionCache {
        address tokenFrom;
        address tokenTo;
        uint256 collateralFrom;
        uint256 collateralTo;
        uint128 tokenFromPremium;
        uint128 tokenToPremium;
        uint256 amountSpent;
        uint256 amountReceived;
        uint128 liquidityAdded;
        uint256 amountFromAdd;
        uint256 amountToAdd;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 token0Owed;
        uint128 token1Owed;
    }

    struct LiquidatePositionCache {
        uint128 tokenFromOwed;
        uint128 tokenToOwed;
        uint128 liquidationRewardFrom;
        uint128 liquidationRewardTo;
    }

    struct OwedInfoCache {
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 feeGrowthInside0X128;
        uint256 feeGrowthInside1X128;
    }

    struct RepayCache {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint160 sqrtRatioX96;
        uint160 sqrtRatioAX96;
        uint160 sqrtRatioBX96;
    }
}
