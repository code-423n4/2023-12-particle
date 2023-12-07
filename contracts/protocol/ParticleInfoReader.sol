// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";
import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IUniswapV3Pool} from "../../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

import {ParticlePositionManager} from "./ParticlePositionManager.sol";
import {Errors} from "../libraries/Errors.sol";
import {Base} from "../libraries/Base.sol";
import {LiquidityPosition} from "../libraries/LiquidityPosition.sol";
import {Lien} from "../libraries/Lien.sol";
import {FullMath} from "../libraries/FullMath.sol";
import {TickMath} from "../libraries/TickMath.sol";
import {LiquidityAmounts} from "../libraries/LiquidityAmounts.sol";
import {DataStruct, DataCache} from "../libraries/Structs.sol";

contract ParticleInfoReader is Ownable2StepUpgradeable, UUPSUpgradeable, Multicall {
    /* Variables */
    // solhint-disable-next-line var-name-mixedcase
    address public PARTICLE_POSITION_MANAGER_ADDR;
    ParticlePositionManager internal _particlePositionManager;

    event UpdateParticleAddress(address particlePositionManager);

    // required by openzeppelin UUPS module
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    constructor() {
        _disableInitializers();
    }

    function initialize(address particleAddr) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        PARTICLE_POSITION_MANAGER_ADDR = particleAddr;
        _particlePositionManager = ParticlePositionManager(particleAddr);
    }

    /*==============================================================
                             Update Address
    ==============================================================*/

    /**
     * @notice Update address of particle position manager
     * @param particleAddr address of particle position manager
     */
    function updateParticleAddress(address particleAddr) external onlyOwner {
        if (particleAddr == address(0)) revert Errors.InvalidValue();
        PARTICLE_POSITION_MANAGER_ADDR = particleAddr;
        _particlePositionManager = ParticlePositionManager(particleAddr);
        emit UpdateParticleAddress(particleAddr);
    }

    /*==============================================================
                            Pool Information
    ==============================================================*/

    /**
     * @notice Helper function getting the pool and current price information
     * @param tokenId tokenId of the liquidity position NFT
     * @return token0 address of token0
     * @return token1 address of token1
     * @return fee pool fee
     * @return tickLower lower tick of the concentrated liquidity position
     * @return tickUpper upper tick of the concentrated liquidity position
     * @return liquidity amount of liquidity
     * @return sqrtRatioX96 the current price of the token pairs of this pool
     */
    function getPoolInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint160 sqrtRatioX96
        )
    {
        (, , token0, token1, fee, tickLower, tickUpper, liquidity, , , , ) = Base.UNI_POSITION_MANAGER.positions(
            tokenId
        );
        IUniswapV3Pool pool = IUniswapV3Pool(Base.UNI_FACTORY.getPool(token0, token1, fee));
        (sqrtRatioX96, , , , , , ) = pool.slot0();
    }

    /**
     * @notice Helper function getting the pool of different price tiers with the deepest liquidity
     * @param token0 address of token0
     * @param token1 address of token1
     * @return deepPool address of the pool with the deepest liquidity
     */
    function getDeepPool(address token0, address token1) external view returns (address deepPool) {
        uint24[3] memory feeTiers = [uint24(500), uint24(3000), uint24(10000)];
        uint128 maxLiquidity = 0;

        for (uint256 i = 0; i < feeTiers.length; i++) {
            address poolAddress = Base.UNI_FACTORY.getPool(token0, token1, feeTiers[i]);
            if (poolAddress != address(0)) {
                IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);
                uint128 liquidity = pool.liquidity();
                if (liquidity > maxLiquidity) {
                    maxLiquidity = liquidity;
                    deepPool = poolAddress;
                }
            }
        }
    }

    /*==============================================================
                           Price and Liquidity
    ==============================================================*/

    /**
     * @notice Helper function getting the pool current price
     * @param token0 token0
     * @param token1 token1
     * @param fee pool fee
     * @return sqrtRatioX96 the current price of this pool
     */
    function getCurrentPrice(address token0, address token1, uint24 fee) external view returns (uint160 sqrtRatioX96) {
        IUniswapV3Pool pool = IUniswapV3Pool(Base.UNI_FACTORY.getPool(token0, token1, fee));
        (sqrtRatioX96, , , , , , ) = pool.slot0();
    }

    /**
     * @notice Helper function getting the pool current price
     * @param poolAddr address of the pool
     * @return sqrtRatioX96 the current price of this pool
     */
    function getCurrentPrice(address poolAddr) external view returns (uint160 sqrtRatioX96) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddr);
        (sqrtRatioX96, , , , , , ) = pool.slot0();
    }

    /**
     * @notice Helper function getting the token amounts required for given liquidity and tick boundaries
     * @param liquidity desired amount of liquidity
     * @param sqrtRatioX96 current price of the token pairs of this pool
     * @param tickLower lower tick of the concentrated liquidity position
     * @param tickUpper upper tick of the concentrated liquidity position
     * @return amount0 amount for token0 at the current price
     * @return amount1 amount for token1 at the current price
     */
    function getAmountsFromLiquidity(
        uint128 liquidity,
        uint160 sqrtRatioX96,
        int24 tickLower,
        int24 tickUpper
    ) external pure returns (uint256 amount0, uint256 amount1) {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity
        );
    }

    /**
     * @notice Helper function getting the token amounts required for given liquidity and tick boundaries
     * @param amount0 desired amount for token0 at the current price
     * @param amount1 desired amount for token1 at the current price
     * @param sqrtRatioX96 current price of the token pairs of this pool
     * @param tickLower lower tick of the concentrated liquidity position
     * @param tickUpper upper tick of the concentrated liquidity position
     * @return liquidity amount of corresponding liquidity
     */
    function getLiquidityFromAmounts(
        uint256 amount0,
        uint256 amount1,
        uint160 sqrtRatioX96,
        int24 tickLower,
        int24 tickUpper
    ) external pure returns (uint128 liquidity) {
        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            amount0,
            amount1
        );
    }

    /*==============================================================
                         Collateral Calculation
    ==============================================================*/
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
    ) external pure returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = Base.getRequiredCollateral(liquidity, tickLower, tickUpper);
    }

    /*==============================================================
                         Position Information
    ==============================================================*/

    /**
     * @notice Get basic information of a liquidity position
     * @param tokenId tokenId of the liquidity position NFT
     * @return owner owner of the liquidity position
     * @return token0 address of token0
     * @return token1 address of token1
     * @return liquidity amount of current available liquidity
     * @return tickLower lower tick of the concentrated liquidity position
     * @return tickUpper upper tick of the concentrated liquidity position
     * @return token0Owed amount of token0 owed to the owner
     * @return token1Owed amount of token1 owed to the owner
     * @return renewalCutoffTime renewal cutoff time for all previous loans
     */
    function getLiquidityPosition(
        uint256 tokenId
    )
        external
        view
        returns (
            address owner,
            address token0,
            address token1,
            uint128 liquidity,
            int24 tickLower,
            int24 tickUpper,
            uint128 token0Owed,
            uint128 token1Owed,
            uint32 renewalCutoffTime
        )
    {
        (owner, renewalCutoffTime, token0Owed, token1Owed) = _particlePositionManager.lps(tokenId);
        (, , token0, token1, , tickLower, tickUpper, liquidity, , , , ) = Base.UNI_POSITION_MANAGER.positions(tokenId);
    }

    struct GetLienCache {
        uint24 token0PremiumPortion;
        uint24 token1PremiumPortion;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0;
        uint256 amount1;
    }

    /**
     * @notice Get basic information of a lien
     * @param borrower address of the borrower
     * @param lienId ID for the existing lien
     * @return tokenId tokenId of the liquidity position NFT
     * @return liquidity amount of liquidity locked in the lien
     * @return startTime start time of the lien
     * @return token0Premium amount of token0 premium locked in the lien
     * @return token1Premium amount of token1 premium locked in the lien
     * @return feeGrowthInside0LastX128 fee growth of token0 since the previous borrow/fee collection time
     * @return feeGrowthInside1LastX128 fee growth of token1 since the previous borrow/fee collection time
     * @return zeroForOne direction of the swap
     */
    function getLien(
        address borrower,
        uint96 lienId
    )
        external
        view
        returns (
            uint40 tokenId,
            uint128 liquidity,
            uint32 startTime,
            uint128 token0Premium,
            uint128 token1Premium,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            bool zeroForOne
        )
    {
        (
            tokenId,
            liquidity,
            ,
            ,
            startTime,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            zeroForOne
        ) = _particlePositionManager.liens(keccak256(abi.encodePacked(borrower, lienId)));
        (token0Premium, token1Premium) = getPremium(borrower, lienId);
    }

    /**
     * @notice Get amount of preimum
     * @param borrower address of the borrower
     * @param lienId ID for the existing lien
     * @return token0Premium amount of token0 premium locked in the lien
     * @return token1Premium amount of token1 premium locked in the lien
     */
    function getPremium(
        address borrower,
        uint96 lienId
    ) public view returns (uint128 token0Premium, uint128 token1Premium) {
        (
            uint40 tokenId,
            uint128 liquidity,
            uint24 token0PremiumPortion,
            uint24 token1PremiumPortion,
            ,
            ,
            ,

        ) = _particlePositionManager.liens(keccak256(abi.encodePacked(borrower, lienId)));

        (, , , , , int24 tickLower, int24 tickUpper, , , , , ) = Base.UNI_POSITION_MANAGER.positions(tokenId);
        (uint256 amount0, uint256 amount1) = Base.getRequiredCollateral(liquidity, tickLower, tickUpper);
        (token0Premium, token1Premium) = Base.getPremium(amount0, amount1, token0PremiumPortion, token1PremiumPortion);
    }

    struct OwedInfoCache {
        uint40 tokenId;
        uint128 liquidity;
        uint24 token0PremiumPortion;
        uint24 token1PremiumPortion;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
    }

    /**
     * @notice Get the current owed fees for a position
     * @param borrower address of the borrower
     * @param lienId ID for the existing lien
     * @return token0Owed amount of token0 owed to the liquidity provider
     * @return token1Owed amount of token1 owed to the liquidity provider
     * @return token0Premium amount of token0 premium locked in the lien
     * @return token1Premium amount of token1 premium locked in the lien
     * @return collateral0 amount of token0 required by the lp (if oneForZero)
     * @return collateral1 amount of token1 required by the lp (if zeroForOne)
     */
    function getOwedInfo(
        address borrower,
        uint96 lienId
    )
        external
        view
        returns (
            uint128 token0Owed,
            uint128 token1Owed,
            uint128 token0Premium,
            uint128 token1Premium,
            uint256 collateral0,
            uint256 collateral1
        )
    {
        OwedInfoCache memory cache;
        (
            cache.tokenId,
            cache.liquidity,
            cache.token0PremiumPortion,
            cache.token1PremiumPortion,
            ,
            cache.feeGrowthInside0LastX128,
            cache.feeGrowthInside1LastX128,

        ) = _particlePositionManager.liens(keccak256(abi.encodePacked(borrower, lienId)));
        (, , token0Owed, token1Owed, token0Premium, token1Premium, collateral0, collateral1) = Base.getOwedInfo(
            DataStruct.OwedInfoParams({
                tokenId: cache.tokenId,
                liquidity: cache.liquidity,
                feeGrowthInside0LastX128: cache.feeGrowthInside0LastX128,
                feeGrowthInside1LastX128: cache.feeGrowthInside1LastX128,
                token0PremiumPortion: cache.token0PremiumPortion,
                token1PremiumPortion: cache.token1PremiumPortion
            })
        );
    }
}
