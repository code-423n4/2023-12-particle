// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console} from "../lib/forge-std/src/Console.sol";
import {IUniswapV3Pool} from "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {DataStruct} from "../contracts/libraries/Structs.sol";
import {LiquidityAmounts} from "../contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "../contracts/libraries/TickMath.sol";
import {Errors} from "../contracts/libraries/Errors.sol";
import {ParticlePositionManagerTestBase} from "./Base.t.sol";

contract ClosePositionTest is ParticlePositionManagerTestBase {
    uint256 public constant MINT_AMOUNT_0 = 15000 * 1e6;
    uint256 public constant MINT_AMOUNT_1 = 10 ether;
    uint128 public constant BORROWER_LIQUIDITY_PORTION = 20;
    uint128 public constant REPAY_LIQUIDITY_PORTION = 1000;
    uint256 public constant BORROWER_AMOUNT_0 = 1500 * 1e6;
    uint256 public constant BORROWER_AMOUNT_1 = 1 ether;
    uint128 public constant PREMIUM_0 = 500 * 1e6;
    uint128 public constant PREMIUM_1 = 0.5 ether;
    uint256 public constant WHALE_LONG_AMOUNT = 150000 * 1e6;
    uint256 public constant WHALE_SHORT_AMOUNT = 100 ether;
    uint256 public constant WHALE_LONG_AMOUNT_MORE = 10000000 * 1e6;
    uint256 public constant WHALE_SHORT_AMOUNT_MORE = 5000 ether;
    int24 public constant TICK_STEP = 200;

    IUniswapV3Pool internal _pool;
    int24 internal _tick;
    int24 internal _tickLower;
    int24 internal _tickUpper;
    uint256 internal _tokenId;
    uint128 internal _liquidity;
    uint160 internal _sqrtRatioAX96;
    uint160 internal _sqrtRatioBX96;
    uint128 internal _borrowerLiquidityPorition;

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

        _borrowerLiquidityPorition = BORROWER_LIQUIDITY_PORTION;
    }

    function _setupUpperOutOfRange() internal {
        _tickLower = ((_tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        _tickUpper = ((_tick + 2 * TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        _sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(_tickLower);
        _sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(_tickUpper);
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
    }

    function _setupLowerOutOfRange() internal {
        _tickLower = ((_tick - 2 * TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        _tickUpper = ((_tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        _sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(_tickLower);
        _sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(_tickUpper);
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
    }

    function _openLongPosition()
        internal
        returns (uint256 amountIn, uint256 amount0ToBorrow, uint256 amount1ToBorrow, uint256 amountSwap)
    {
        (uint160 sqrtRatioX96, , , , , , ) = _pool.slot0();
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
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
        uint256 eps = amountIn / 1000; // 0.1% tolerance, will be added into premium
        amountIn += eps;

        _borrowToLong(SWAPPER, address(USDC), _tokenId, amountIn, amount0ToBorrow, borrowerLiquidity);
    }

    function _openShortPosition()
        internal
        returns (uint256 amountIn, uint256 amount0ToBorrow, uint256 amount1ToBorrow, uint256 amountSwap)
    {
        (uint160 sqrtRatioX96, , , , , , ) = _pool.slot0();
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
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
        uint256 eps = amountIn / 1000; // 0.1% tolerance, will be added into premium
        amountIn += eps;

        _borrowToShort(SWAPPER, address(WETH), _tokenId, amountIn, amount1ToBorrow, borrowerLiquidity);
    }

    function _prepareCloseLongPosition(
        uint256 lienId,
        bool swapback,
        bool liquidityTolerance
    ) internal returns (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap, bytes memory data) {
        // get lien info
        (, uint128 liquidity, , , , , , ) = particlePositionManager.liens(
            keccak256(abi.encodePacked(SWAPPER, uint96(lienId)))
        );

        // add back liquidity requirement
        /// @dev need REPAY_LIQUIDITY_PORTION to factor in the price impact after swap, making returned amount different
        (uint160 currSqrtRatioX96, , , , , , ) = _pool.slot0();
        (amount0ToReturn, amount1ToReturn) = LiquidityAmounts.getAmountsForLiquidity(
            currSqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            liquidityTolerance ? liquidity + liquidity / REPAY_LIQUIDITY_PORTION : liquidity
        );
        (, uint256 ethCollateral) = particleInfoReader.getRequiredCollateral(liquidity, _tickLower, _tickUpper);

        // get swap data
        uint160 currentPrice = particleInfoReader.getCurrentPrice(address(USDC), address(WETH), FEE);
        if (swapback) {
            amountSwap = ethCollateral - amount1ToReturn;
        } else {
            amountSwap = QUOTER.quoteExactOutputSingle(address(WETH), address(USDC), FEE, amount0ToReturn, 0);
        }
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

    function _closeLongPosition(
        uint256 lienId,
        bool swapback,
        bool liquidityTolerance
    ) internal returns (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap) {
        bytes memory data;
        (amount0ToReturn, amount1ToReturn, amountSwap, data) = _prepareCloseLongPosition(
            lienId,
            swapback,
            liquidityTolerance
        );

        // close position
        vm.startPrank(SWAPPER);
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: uint96(lienId),
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function _prepareCloseShortPosition(
        uint256 lienId,
        bool swapback,
        bool liquidityTolerance
    ) internal returns (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap, bytes memory data) {
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
            liquidityTolerance ? liquidity + liquidity / REPAY_LIQUIDITY_PORTION : liquidity
        );
        (uint256 usdcCollateral, ) = particleInfoReader.getRequiredCollateral(liquidity, _tickLower, _tickUpper);

        // get swap data
        uint160 currentPrice = particleInfoReader.getCurrentPrice(address(USDC), address(WETH), FEE);
        if (swapback) {
            amountSwap = usdcCollateral - amount0ToReturn;
        } else {
            amountSwap = QUOTER.quoteExactOutputSingle(address(USDC), address(WETH), FEE, amount1ToReturn, 0);
        }
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

    function _closeShortPosition(
        uint256 lienId,
        bool swapback,
        bool liquidityTolerance
    ) internal returns (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap) {
        bytes memory data;
        (amount0ToReturn, amount1ToReturn, amountSwap, data) = _prepareCloseShortPosition(
            lienId,
            swapback,
            liquidityTolerance
        );

        // close position
        vm.startPrank(SWAPPER);
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: uint96(lienId),
                repayFrom: amount0ToReturn,
                repayTo: amount1ToReturn,
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function _addPremium(uint96 lienId, uint128 premium0, uint128 premium1) internal {
        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, premium0);
        WETH.transfer(SWAPPER, premium1);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), premium0);
        TransferHelper.safeApprove(address(WETH), address(particlePositionManager), premium1);
        particlePositionManager.addPremium(lienId, premium0, premium1);
        vm.stopPrank();
    }

    function testOpensBasicLongShortFromSameLp() public {
        _openLongPosition();
        _openShortPosition();
    }

    function testOpensFullLongShortFromSameLp() public {
        _borrowerLiquidityPorition = 2;
        _openLongPosition();
        _openShortPosition();
    }

    function testOpenLongWhaleLongClose() public {
        _openLongPosition();
        // whale moves market to long
        _swap(WHALE, address(USDC), address(WETH), FEE, WHALE_LONG_AMOUNT);
        // close position
        _closeLongPosition(0, true, true);
    }

    function testOpenLongWhaleLongCloseNotSwapBack() public {
        _openLongPosition();
        // whale moves market to long
        _swap(WHALE, address(USDC), address(WETH), FEE, WHALE_LONG_AMOUNT);
        // close position
        _closeLongPosition(0, false, true);
    }

    function testOpenLongWhaleShortClose() public {
        _openLongPosition();
        // whale moves market to short
        _swap(WHALE, address(WETH), address(USDC), FEE, WHALE_SHORT_AMOUNT);
        // close position
        _closeLongPosition(0, true, true);
    }

    function testOpenLongWhaleShortLiquidation() public {
        _openLongPosition();
        // whale moves market to short
        _swap(WHALE, address(WETH), address(USDC), FEE, WHALE_SHORT_AMOUNT_MORE);
        // close position
        (uint160 currSqrtRatioX96, , , , , , ) = _pool.slot0();
        if (currSqrtRatioX96 < _sqrtRatioBX96) {
            console.log("---- LIQUIDATION CONDITION NOT MET ----");
            console.log("Try increasing WHALE_SHORT_AMOUNT_MORE");
            console.log("currSqrtRatioX96", currSqrtRatioX96);
            console.log("_sqrtRatioBX96", _sqrtRatioBX96);
        } else {
            _closeLongPosition(0, true, false);
        }
    }

    function testLongCannotOverspendFromPosition() public {
        _openLongPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseLongPosition(0, true, true);

        (, uint128 tokenFromPremium) = particleInfoReader.getPremium(SWAPPER, 0);

        // close position
        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.OverSpend.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap + tokenFromPremium + 1, // overspend
                data: data
            })
        );
        vm.stopPrank();
    }

    function testLongCanSpendAllPremiumFromPosition() public {
        _openLongPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseLongPosition(0, true, true);

        (, uint128 tokenFromPremium) = particleInfoReader.getPremium(SWAPPER, 0);

        // close position
        vm.startPrank(SWAPPER);
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap + tokenFromPremium, // all premium
                data: data
            })
        );
        vm.stopPrank();
    }

    function testLongCannotOverpayFromPosition() public {
        _openLongPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseLongPosition(0, true, true);

        // close position
        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientSwap.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn + amount0ToReturn / 10, // overpay
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testLongCannotOverspendFromData() public {
        _openLongPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseLongPosition(0, true, true);

        (, uint128 liquidity, , , , , , ) = particlePositionManager.liens(
            keccak256(abi.encodePacked(SWAPPER, uint96(0)))
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
            amountIn: amountSwap + 1, // overspend in data
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice + currentPrice / SLIPPAGE_FACTOR
        });
        data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.SwapFailed.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testNonParticleRecipientInSwapData() public {
        _openLongPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseLongPosition(0, true, true);

        (, uint128 liquidity, , , , , , ) = particlePositionManager.liens(
            keccak256(abi.encodePacked(SWAPPER, uint96(0)))
        );

        (, uint256 ethCollateral) = particleInfoReader.getRequiredCollateral(liquidity, _tickLower, _tickUpper);

        // get swap data
        uint160 currentPrice = particleInfoReader.getCurrentPrice(address(USDC), address(WETH), FEE);
        amountSwap = ethCollateral - amount1ToReturn;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(USDC),
            fee: FEE,
            recipient: SWAPPER, // non particle recipient
            deadline: block.timestamp,
            amountIn: amountSwap,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice + currentPrice / SLIPPAGE_FACTOR
        });
        data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientSwap.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testLongCannotUnderpayToLp() public {
        _openLongPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseLongPosition(0, true, true);

        // close position
        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientRepay.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount1ToReturn - amount1ToReturn / 10, // underpay
                repayTo: amount0ToReturn - amount0ToReturn / 10, // underpay
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testOpenLongThenCloseFeeCost() public {
        (
            uint256 amountIn,
            uint256 amount0ToBorrow,
            uint256 amount1ToBorrow,
            uint256 openAmountSwap
        ) = _openLongPosition();
        (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 closeAmountSwap) = _closeLongPosition(0, true, true);
        uint256 feeCost = amountIn - USDC.balanceOf(address(SWAPPER));
        uint256 usdcCost = (openAmountSwap * FEE) /
            BASIS_POINT +
            (openAmountSwap * FEE_FACTOR) /
            BASIS_POINT +
            amount0ToReturn -
            amount0ToBorrow;
        uint256 ethCost = (closeAmountSwap * FEE) / BASIS_POINT + amount1ToReturn - amount1ToBorrow;
        uint256 convertedUsdcCost = QUOTER.quoteExactOutputSingle(address(USDC), address(WETH), FEE, ethCost, 0);
        assertLt(feeCost, usdcCost + convertedUsdcCost);
    }

    function testOpenShortWhaleShortClose() public {
        _openShortPosition();
        // whale moves market to short
        _swap(WHALE, address(WETH), address(USDC), FEE, WHALE_SHORT_AMOUNT);
        // close position
        _closeShortPosition(0, true, true);
    }

    function testOpenShortWhaleShortCloseNotSwapBack() public {
        _openShortPosition();
        // whale moves market to short
        _swap(WHALE, address(WETH), address(USDC), FEE, WHALE_SHORT_AMOUNT);
        // close position
        _closeShortPosition(0, false, true);
    }

    function testOpenShortWhaleLongClose() public {
        _openShortPosition();
        // whale moves market to long
        _swap(WHALE, address(USDC), address(WETH), FEE, WHALE_LONG_AMOUNT);
        // close position
        _closeShortPosition(0, true, true);
    }

    function testOpenShortWhaleLongLiquidation() public {
        _openShortPosition();
        // whale moves market to long
        _swap(WHALE, address(USDC), address(WETH), FEE, WHALE_LONG_AMOUNT_MORE);
        // close position
        (uint160 currSqrtRatioX96, , , , , , ) = _pool.slot0();
        if (currSqrtRatioX96 > _sqrtRatioAX96) {
            console.log("---- LIQUIDATION CONDITION NOT MET ----");
            console.log("Try increasing WHALE_LONG_AMOUNT_MORE");
            console.log("currSqrtRatioX96", currSqrtRatioX96);
            console.log("_sqrtRatioAX96", _sqrtRatioBX96);
        } else {
            _closeShortPosition(0, true, false);
        }
    }

    function testShortCannotOverspendFromPosition() public {
        _openShortPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseShortPosition(0, true, true);
        (uint128 tokenFromPremium, ) = particleInfoReader.getPremium(SWAPPER, 0);

        // close position
        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.OverSpend.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount0ToReturn,
                repayTo: amount1ToReturn,
                amountSwap: amountSwap + tokenFromPremium + 1, // overspend
                data: data
            })
        );
        vm.stopPrank();
    }

    function testShortCannotOverpayFromPosition() public {
        _openShortPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseShortPosition(0, true, true);

        // close position
        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientSwap.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount0ToReturn,
                repayTo: amount1ToReturn + amount1ToReturn / 10, // overpay
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testShortCannotOverspendFromData() public {
        _openShortPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseShortPosition(0, true, true);

        // get lien info
        (, uint128 liquidity, , , , , , ) = particlePositionManager.liens(
            keccak256(abi.encodePacked(SWAPPER, uint96(0)))
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
            amountIn: amountSwap + 1, // overspend
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice - currentPrice / SLIPPAGE_FACTOR
        });
        data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        // close position
        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.SwapFailed.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount0ToReturn,
                repayTo: amount1ToReturn,
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testShortCannotUnderpayToLp() public {
        _openShortPosition();

        (
            uint256 amount0ToReturn,
            uint256 amount1ToReturn,
            uint256 amountSwap,
            bytes memory data
        ) = _prepareCloseShortPosition(0, true, true);

        // close position
        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientRepay.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount0ToReturn - amount0ToReturn / 10, // underpay
                repayTo: amount1ToReturn - amount1ToReturn / 10, // underpay
                amountSwap: amountSwap,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testOpenShortThenCloseFeeCost() public {
        (
            uint256 amountIn,
            uint256 amount0ToBorrow,
            uint256 amount1ToBorrow,
            uint256 openAmountSwap
        ) = _openShortPosition();
        (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 closeAmountSwap) = _closeShortPosition(
            0,
            true,
            true
        );
        uint256 feeCost = amountIn - WETH.balanceOf(address(SWAPPER));
        uint256 ethCost = (openAmountSwap * FEE) /
            BASIS_POINT +
            (openAmountSwap * FEE_FACTOR) /
            BASIS_POINT +
            amount1ToReturn -
            amount1ToBorrow;
        uint256 usdcCost = (closeAmountSwap * FEE) / BASIS_POINT + amount0ToReturn - amount0ToBorrow;
        uint256 convertedEthCost = QUOTER.quoteExactOutputSingle(address(WETH), address(USDC), FEE, usdcCost, 0);
        assertLt(feeCost, ethCost + convertedEthCost);
    }

    function testNonBorrowerCannotClose() public {
        _openLongPosition();
        vm.startPrank(WHALE);
        vm.expectRevert(abi.encodeWithSelector(Errors.RecordEmpty.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({lienId: 0, repayFrom: 0, repayTo: 0, amountSwap: 0, data: new bytes(0)})
        );
        vm.stopPrank();
    }

    function testOpenLongOutOfRangeWhaleLongClose() public {
        _setupUpperOutOfRange();
        testOpenLongWhaleLongClose();
    }

    function testOpenLongOutOfRangeWhaleShortClose() public {
        _setupUpperOutOfRange();
        testOpenLongWhaleShortClose();
    }

    function testOpenLongOutOfRangeWhaleShortLiquidation() public {
        _setupUpperOutOfRange();
        testOpenLongWhaleShortLiquidation();
    }

    function testOpenShortOutOfRangeWhaleShortClose() public {
        _setupLowerOutOfRange();
        testOpenShortWhaleShortClose();
    }

    function testOpenShortOutOfRangeWhaleLongClose() public {
        _setupLowerOutOfRange();
        testOpenShortWhaleLongClose();
    }

    function testOpenShortOutOfRangeWhaleLongLiquidation() public {
        _setupLowerOutOfRange();
        testOpenShortWhaleLongLiquidation();
    }

    function testOpenLongCloseLiquidityAmount() public {
        (, , , , , , , uint128 liquidityBefore, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        _openLongPosition();
        _closeLongPosition(0, true, true);
        (, , , , , , , uint128 liquidityAfter, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        assertGe(liquidityAfter + liquidityAfter / BASIS_POINT, liquidityBefore);
    }

    function testOpenLongWhaleLongCloseLiquidityAmount() public {
        (, , , , , , , uint128 liquidityBefore, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        testOpenLongWhaleLongClose();
        (, , , , , , , uint128 liquidityAfter, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        assertGe(liquidityAfter + liquidityAfter / BASIS_POINT, liquidityBefore);
    }

    function testOpenLongWhaleShortCloseLiquidityAmount() public {
        (, , , , , , , uint128 liquidityBefore, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        testOpenLongWhaleShortClose();
        (, , , , , , , uint128 liquidityAfter, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        assertGe(liquidityAfter + liquidityAfter / BASIS_POINT, liquidityBefore);
    }

    function testOpenShortCloseLiquidityAmount() public {
        (, , , , , , , uint128 liquidityBefore, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        _openShortPosition();
        _closeShortPosition(0, true, true);
        (, , , , , , , uint128 liquidityAfter, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        assertGe(liquidityAfter + liquidityAfter / BASIS_POINT, liquidityBefore);
    }

    function testOpenShortWhaleShortCloseLiquidityAmount() public {
        (, , , , , , , uint128 liquidityBefore, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        testOpenShortWhaleShortClose();
        (, , , , , , , uint128 liquidityAfter, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        assertGe(liquidityAfter + liquidityAfter / BASIS_POINT, liquidityBefore);
    }

    function testOpenShortWhaleLongCloseLiquidityAmount() public {
        (, , , , , , , uint128 liquidityBefore, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        testOpenShortWhaleLongClose();
        (, , , , , , , uint128 liquidityAfter, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        assertGe(liquidityAfter + liquidityAfter / BASIS_POINT, liquidityBefore);
    }

    function testOpenLongCloseCannotEscapeOwedAmount() public {
        _openLongPosition();
        _addPremium(0, PREMIUM_0, PREMIUM_1);

        // generate a lot fees
        for (uint256 i = 0; i < 10; i++) {
            _swap(WHALE, address(USDC), address(WETH), FEE, WHALE_LONG_AMOUNT);
            _swap(WHALE, address(WETH), address(USDC), FEE, WHALE_SHORT_AMOUNT);
        }

        (uint256 amount0ToReturn, uint256 amount1ToReturn, uint256 amountSwap, ) = _prepareCloseLongPosition(
            0,
            true,
            true
        );

        ///@dev factor in rounding approximation
        (, uint128 actualPremium1) = particleInfoReader.getPremium(SWAPPER, 0);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(WETH),
            tokenOut: address(USDC),
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountSwap + actualPremium1, // swap everything to escape owed
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        vm.startPrank(SWAPPER);
        vm.expectRevert(abi.encodeWithSelector(Errors.OverRefund.selector));
        particlePositionManager.closePosition(
            DataStruct.ClosePositionParams({
                lienId: 0,
                repayFrom: amount1ToReturn,
                repayTo: amount0ToReturn,
                amountSwap: amountSwap + actualPremium1,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testBorrowToLongAdminCanWithdrawTreasury() public {
        _openLongPosition();
        _closeLongPosition(0, true, true);
        uint256 fee = USDC.balanceOf(address(particlePositionManager));
        vm.startPrank(ADMIN);
        particlePositionManager.withdrawTreasury(address(USDC), ADMIN);
        assertEq(USDC.balanceOf(address(ADMIN)), (fee * TREASURY_RATE) / BASIS_POINT);
        assertGt(fee, 0);
        vm.stopPrank();
    }

    function testBorrowToShortAdminCanWithdrawTreasury() public {
        _openShortPosition();
        _closeShortPosition(0, true, true);
        uint256 fee = WETH.balanceOf(address(particlePositionManager));
        vm.startPrank(ADMIN);
        particlePositionManager.withdrawTreasury(address(WETH), ADMIN);
        assertEq(WETH.balanceOf(address(ADMIN)), (fee * TREASURY_RATE) / BASIS_POINT);
        assertGt(fee, 0);
        vm.stopPrank();
    }

    function testAdminCannotWtihdrawTreasuryToNull() public {
        _openLongPosition();
        _closeLongPosition(0, true, true);
        vm.startPrank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidRecipient.selector));
        particlePositionManager.withdrawTreasury(address(USDC), address(0));
        vm.stopPrank();
    }
}
