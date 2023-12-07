// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IUniswapV3Pool} from "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {DataStruct} from "../contracts/libraries/Structs.sol";
import {LiquidityAmounts} from "../contracts/libraries/LiquidityAmounts.sol";
import {Base} from "../contracts/libraries/Base.sol";
import {Lien} from "../contracts/libraries/Lien.sol";
import {TickMath} from "../contracts/libraries/TickMath.sol";
import {Errors} from "../contracts/libraries/Errors.sol";
import {ParticlePositionManagerTestBase} from "./Base.t.sol";

contract LiquidationTest is ParticlePositionManagerTestBase {
    uint256 public constant MINT_AMOUNT_0 = 15000 * 1e6;
    uint256 public constant MINT_AMOUNT_1 = 10 ether;
    uint128 public constant PREMIUM_0 = 500 * 1e6;
    uint128 public constant PREMIUM_1 = 0.5 ether;
    uint128 public constant BORROWER_LIQUIDITY_PORTION = 20;
    uint128 public constant REPAY_LIQUIDITY_PORTION = 1000;
    uint256 public constant BORROWER_AMOUNT_0 = 1500 * 1e6;
    uint256 public constant BORROWER_AMOUNT_1 = 1 ether;
    int24 public constant TICK_STEP = 200;
    uint96 public constant LIEN_ID = 0;
    address public constant LIQUIDATOR = payable(address(0x7777));

    IUniswapV3Pool internal _pool;
    int24 internal _tick;
    int24 internal _tickLower;
    int24 internal _tickUpper;
    uint256 internal _tokenId;
    uint128 internal _liquidity;
    uint160 internal _sqrtRatioAX96;
    uint160 internal _sqrtRatioBX96;

    function setUp() public override {
        super.setUp();

        _pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, _tick, , , , , ) = _pool.slot0();

        _tickLower = ((_tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        _tickUpper = ((_tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (_tokenId, , , ) = _mint(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            _tickLower,
            _tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );

        (, , , , , , , _liquidity, , , , ) = nonfungiblePositionManager.positions(_tokenId);

        _sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(_tickLower);
        _sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(_tickUpper);
    }

    function _openLongPosition()
        internal
        returns (uint256 amountIn, uint256 amount0ToBorrow, uint256 amount1ToBorrow, uint256 amountSwap)
    {
        (uint160 sqrtRatioX96, , , , , , ) = _pool.slot0();
        uint128 borrowerLiquidity = _liquidity / BORROWER_LIQUIDITY_PORTION;
        (amount0ToBorrow, amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        (, uint256 requiredCollateral) = particleInfoReader.getRequiredCollateral(
            borrowerLiquidity,
            _tickLower,
            _tickUpper
        );
        amountSwap = QUOTER.quoteExactOutputSingle(
            address(USDC),
            address(WETH),
            FEE,
            requiredCollateral - amount1ToBorrow,
            0
        );
        amountIn = amountSwap - amount0ToBorrow;
        uint256 eps = amountIn / 1000; // 0.1% tolerance
        amountIn += eps;

        _borrowToLong(SWAPPER, address(USDC), _tokenId, amountIn, amount0ToBorrow, borrowerLiquidity);
    }

    function _openShortPosition()
        internal
        returns (uint256 amountIn, uint256 amount0ToBorrow, uint256 amount1ToBorrow, uint256 amountSwap)
    {
        (uint160 sqrtRatioX96, , , , , , ) = _pool.slot0();
        uint128 borrowerLiquidity = _liquidity / BORROWER_LIQUIDITY_PORTION;
        (amount0ToBorrow, amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        (uint256 requiredCollateral, ) = particleInfoReader.getRequiredCollateral(
            borrowerLiquidity,
            _tickLower,
            _tickUpper
        );
        amountSwap = QUOTER.quoteExactOutputSingle(
            address(WETH),
            address(USDC),
            FEE,
            requiredCollateral - amount0ToBorrow,
            0
        );
        amountIn = amountSwap - amount1ToBorrow;
        uint256 eps = amountIn / 1000; // 0.1% tolerance
        amountIn += eps;

        _borrowToShort(SWAPPER, address(WETH), _tokenId, amountIn, amount1ToBorrow, borrowerLiquidity);
    }

    function _prepareCloseLongPosition(
        uint256 lienId
    ) internal view returns (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap, bytes memory data) {
        // get lien info
        (, uint128 liquidity, , , , , , ) = particlePositionManager.liens(
            keccak256(abi.encodePacked(SWAPPER, uint96(lienId)))
        );

        // add back liquidity requirement
        (uint160 currSqrtRatioX96, , , , , , ) = _pool.slot0();
        (amount0ToReturn, amount1ToReturn) = LiquidityAmounts.getAmountsForLiquidity(
            currSqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            liquidity + liquidity / REPAY_LIQUIDITY_PORTION
        );
        (, uint256 ethCollateral) = particleInfoReader.getRequiredCollateral(liquidity, _tickLower, _tickUpper);

        // get swap data
        uint160 currentPrice = particleInfoReader.getCurrentPrice(address(USDC), address(WETH), FEE);
        amountSwap = ethCollateral - amount1ToReturn;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(USDC),
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountSwap,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice + currentPrice / SLIPPAGE_FACTOR
        });
        data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);
    }

    function _prepareCloseShortPosition(
        uint256 lienId
    ) internal view returns (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap, bytes memory data) {
        // get lien info
        (, uint128 liquidity, , , , , , ) = particlePositionManager.liens(
            keccak256(abi.encodePacked(SWAPPER, uint96(lienId)))
        );

        // add back liquidity requirement
        (uint160 currSqrtRatioX96, , , , , , ) = _pool.slot0();
        (amount0ToReturn, amount1ToReturn) = LiquidityAmounts.getAmountsForLiquidity(
            currSqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            liquidity + liquidity / REPAY_LIQUIDITY_PORTION
        );
        (uint256 usdcCollateral, ) = particleInfoReader.getRequiredCollateral(liquidity, _tickLower, _tickUpper);

        // get swap data
        uint160 currentPrice = particleInfoReader.getCurrentPrice(address(USDC), address(WETH), FEE);
        amountSwap = usdcCollateral - amount0ToReturn;

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountSwap,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice - currentPrice / SLIPPAGE_FACTOR
        });
        data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);
    }

    function _liquidateLongPosition(
        uint256 lienId
    ) internal returns (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap) {
        bytes memory data;
        (amount0ToReturn, amount1ToReturn, amountSwap, data) = _prepareCloseLongPosition(lienId);

        // liquidate position
        vm.startPrank(LIQUIDATOR);
        particlePositionManager.liquidatePosition(
            DataStruct.ClosePositionParams({
                lienId: uint96(lienId),
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap,
                data: data
            }),
            SWAPPER
        );
        vm.stopPrank();
    }

    function _liquidateShortPosition(
        uint256 lienId
    ) internal returns (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap) {
        bytes memory data;
        (amount0ToReturn, amount1ToReturn, amountSwap, data) = _prepareCloseShortPosition(lienId);

        // liquidate position
        vm.startPrank(LIQUIDATOR);
        particlePositionManager.liquidatePosition(
            DataStruct.ClosePositionParams({
                lienId: uint96(lienId),
                repayFrom: amount0ToReturn,
                repayTo: amount1ToReturn,
                amountSwap: amountSwap,
                data: data
            }),
            SWAPPER
        );
        vm.stopPrank();
    }

    function _addPremium(uint128 premium0, uint128 premium1) internal {
        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, premium0);
        WETH.transfer(SWAPPER, premium1);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), premium0);
        TransferHelper.safeApprove(address(WETH), address(particlePositionManager), premium1);
        particlePositionManager.addPremium(LIEN_ID, premium0, premium1);
        vm.stopPrank();
    }

    function _renewalCutoff() internal {
        vm.startPrank(LP);
        particlePositionManager.reclaimLiquidity(_tokenId);
        vm.stopPrank();
    }

    function testCanAddPremiumAfterOpeningPosition() public {
        _openLongPosition();
        (uint128 token0PremiumBefore, uint128 token1PremiumBefore) = particleInfoReader.getPremium(SWAPPER, 0);
        _addPremium(PREMIUM_0, PREMIUM_1);
        bytes32 lienKey = keccak256(abi.encodePacked(SWAPPER, LIEN_ID));
        (
            ,
            uint128 liquidity,
            uint24 token0PremiumPortion,
            uint24 token1PremiumPortion,
            ,
            ,
            ,

        ) = particlePositionManager.liens(lienKey);
        (uint256 collateral0, uint256 collateral1) = Base.getRequiredCollateral(liquidity, _tickLower, _tickUpper);
        ///@dev use a different library to get premium to cross check
        (uint128 token0Premium, uint128 token1Premium) = Base.getPremium(
            collateral0,
            collateral1,
            token0PremiumPortion,
            token1PremiumPortion
        );
        assertApproxEqRel(token0PremiumBefore + PREMIUM_0, token0Premium, 0.001e18);
        assertApproxEqRel(token1PremiumBefore + PREMIUM_1, token1Premium, 0.001e18);
    }

    function testCannotAddOthersPremium() public {
        vm.startPrank(WHALE);
        vm.expectRevert(abi.encodeWithSelector(Errors.RecordEmpty.selector));
        particlePositionManager.addPremium(LIEN_ID, PREMIUM_0, PREMIUM_1);
        vm.stopPrank();
    }

    function testCannotOverAddPremium() public {
        _openLongPosition();
        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, PREMIUM_0);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), PREMIUM_0);
        vm.expectRevert(bytes("STF"));
        particlePositionManager.addPremium(LIEN_ID, PREMIUM_0 + 1, 0); // overspend
        vm.stopPrank();
    }

    function testCannotAddPreimumAfterCutoff() public {
        _openLongPosition();
        vm.warp(block.timestamp + 1 seconds);
        _renewalCutoff();
        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.RenewalDisabled.selector));
        particlePositionManager.addPremium(LIEN_ID, PREMIUM_0, PREMIUM_1);
        vm.stopPrank();
    }

    function testCanLiquidateZeroPremiumGetReward() public {
        _openLongPosition();
        (uint128 token0Premium, uint128 token1Premium) = particleInfoReader.getPremium(SWAPPER, 0);
        (, , uint128 token0OwedBefore, ) = particlePositionManager.lps(_tokenId);
        uint256 ethBefore = WETH.balanceOf(LIQUIDATOR);
        _liquidateLongPosition(LIEN_ID); ///@dev tokenOwed won't be zero because fee is generated from borrowed swapping
        (, , uint128 token0OwedAfter, ) = particlePositionManager.lps(_tokenId);
        assertEq(token0Premium, 0); // no additional amount for token0 in long direction, all swap away
        assertGt(token1Premium, 0); //  at position openinig, there is some slack to swap from token0 add premium in token1
        assertEq(token0OwedBefore, token0OwedAfter); // since premium was zero
        // liquidator get rewarded
        assertEq(ethBefore + (token1Premium * LIQUIDATION_REWARD_FACTOR) / BASIS_POINT, WETH.balanceOf(LIQUIDATOR));
    }

    function testCannotLiquidateWithEnoughPreimum() public {
        _openLongPosition();
        _addPremium(PREMIUM_0, PREMIUM_1);

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseLongPosition(LIEN_ID);

        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(abi.encodeWithSelector(Errors.LiquidationNotMet.selector));
        particlePositionManager.liquidatePosition(
            DataStruct.ClosePositionParams({
                lienId: uint96(LIEN_ID),
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap,
                data: data
            }),
            SWAPPER
        );
        vm.stopPrank();
    }

    function testCanLiquidateWithEnoughPremiumAfterCutoffTimeout() public {
        _openLongPosition();
        _addPremium(PREMIUM_0, PREMIUM_1);
        vm.warp(block.timestamp + 1 seconds);
        _renewalCutoff();
        vm.warp(block.timestamp + 7 days);
        _liquidateLongPosition(LIEN_ID);
    }

    function testCannotLiquidateWithEnoughPremiumBeforeCutoffTimeout() public {
        _openLongPosition();
        _addPremium(PREMIUM_0, PREMIUM_1);
        vm.warp(block.timestamp + 1 seconds);
        _renewalCutoff();
        vm.warp(block.timestamp + 7 days - 1 seconds);
        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseLongPosition(LIEN_ID);

        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(abi.encodeWithSelector(Errors.LiquidationNotMet.selector));
        particlePositionManager.liquidatePosition(
            DataStruct.ClosePositionParams({
                lienId: uint96(LIEN_ID),
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap,
                data: data
            }),
            SWAPPER
        );
        vm.stopPrank();
    }

    function testLiquidationRewardAmount() public {
        _openLongPosition();
        _addPremium(PREMIUM_0, PREMIUM_1);
        vm.warp(block.timestamp + 1 seconds);
        _renewalCutoff();
        vm.warp(block.timestamp + 7 days);

        uint256 usdcBefore = USDC.balanceOf(LIQUIDATOR);
        uint256 wethBefore = WETH.balanceOf(LIQUIDATOR);

        (, , uint128 token0Premium, uint128 token1Premium, , ) = particleInfoReader.getOwedInfo(SWAPPER, LIEN_ID);
        _liquidateLongPosition(LIEN_ID);
        assertEq(USDC.balanceOf(LIQUIDATOR) - usdcBefore, (token0Premium * LIQUIDATION_REWARD_FACTOR) / BASIS_POINT);
        assertEq(WETH.balanceOf(LIQUIDATOR) - wethBefore, (token1Premium * LIQUIDATION_REWARD_FACTOR) / BASIS_POINT);
    }

    function testLiquidationOwedAmount() public {
        ///@dev in openPosition, we store the feeGrowthInside first, then swap, which will change the feeGrowth
        ///     and, swap step will have extra fee factor in owed amount, here we only want to check the owed fee due
        ///     to swap happening in the underlying pool. So we get feeGrowth before open position and after liquidation
        (uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) = Base.getFeeGrowthInside(
            address(USDC),
            address(WETH),
            FEE,
            _tickLower,
            _tickUpper
        );
        _openLongPosition();
        (, , uint128 token0OwedBefore, uint128 token1OwedBefore) = particlePositionManager.lps(_tokenId);

        _addPremium(PREMIUM_0, PREMIUM_1);
        vm.warp(block.timestamp + 1 seconds);
        _renewalCutoff();
        vm.warp(block.timestamp + 7 days);

        (, uint128 liquidity, , , , , , ) = particleInfoReader.getLien(SWAPPER, LIEN_ID);

        _liquidateLongPosition(LIEN_ID);

        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = Base.getFeeGrowthInside(
            address(USDC),
            address(WETH),
            FEE,
            _tickLower,
            _tickUpper
        );
        ///@dev token1Owed actual amount needs to factor in the final swap, we compute it separately here
        (uint128 token0Owed, uint128 token1Owed) = Base.getOwedFee(
            feeGrowthInside0X128,
            feeGrowthInside1X128,
            feeGrowthInside0LastX128,
            feeGrowthInside1LastX128,
            liquidity
        );
        (, , uint128 token0OwedAfter, uint128 token1OwedAfter) = particlePositionManager.lps(_tokenId);

        assertEq(token0OwedBefore + token0Owed, token0OwedAfter); // owed amount for token0 is correct
        assertEq(token1OwedBefore + token1Owed, token1OwedAfter); // owed amount for token1 is correct

        vm.startPrank(LP);
        uint256 lpUsdcBefore = USDC.balanceOf(LP);
        uint256 lpWethBefore = WETH.balanceOf(LP);
        particlePositionManager.collectLiquidity(_tokenId);
        assertGe(USDC.balanceOf(LP) - lpUsdcBefore, token0OwedAfter);
        assertGe(WETH.balanceOf(LP) - lpWethBefore, token1OwedAfter);
        vm.stopPrank();
    }
}
