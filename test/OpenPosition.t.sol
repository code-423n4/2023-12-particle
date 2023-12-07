// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IUniswapV3Pool} from "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {DataStruct} from "../contracts/libraries/Structs.sol";
import {LiquidityAmounts} from "../contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "../contracts/libraries/TickMath.sol";
import {Errors} from "../contracts/libraries/Errors.sol";
import {ParticlePositionManagerTestBase} from "./Base.t.sol";

contract OpenPositionTest is ParticlePositionManagerTestBase {
    uint256 public constant MINT_AMOUNT_0 = 15000 * 1e6;
    uint256 public constant MINT_AMOUNT_1 = 10 ether;
    uint128 public constant BORROWER_LIQUIDITY_PORTION = 20;
    uint256 public constant BORROWER_AMOUNT_0 = 1500 * 1e6;
    uint256 public constant BORROWER_AMOUNT_1 = 1 ether;
    int24 public constant TICK_STEP = 200;

    int24 internal _tick;
    int24 internal _tickLower;
    int24 internal _tickUpper;
    uint256 internal _tokenId;
    uint128 internal _liquidity;
    uint160 internal _sqrtRatioX96;
    uint160 internal _sqrtRatioAX96;
    uint160 internal _sqrtRatioBX96;
    uint128 internal _borrowerLiquidityPorition;
    uint160 internal _currentPrice;
    uint160 internal _longPriceBound;
    uint160 internal _shortPriceBound;

    function setUp() public virtual override {
        super.setUp();

        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (_sqrtRatioX96, _tick, , , , , ) = pool.slot0();

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

        _currentPrice = particleInfoReader.getCurrentPrice(address(USDC), address(WETH), FEE);
        _longPriceBound = _currentPrice + _currentPrice / SLIPPAGE_FACTOR;
        _shortPriceBound = _currentPrice - _currentPrice / SLIPPAGE_FACTOR;
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
        _tickUpper = ((_tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
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

    function testRequiredCollateralIndependentOfPrice() public {
        int24 tickLower = (int24(201760) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = (int24(202540) / TICK_SPACING) * TICK_SPACING;
        uint128 liquidity = 1102315340287307;
        (uint256 token0Amount, uint256 token1Amount) = particleInfoReader.getRequiredCollateral(
            liquidity,
            tickLower,
            tickUpper
        );
        assertEq(token1Amount, 1051767454788208747);
        assertEq(token0Amount, 1757246963);
    }

    function testBaseOpenLongPosition() public {
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        (, uint256 requiredEth) = particleInfoReader.getRequiredCollateral(borrowerLiquidity, _tickLower, _tickUpper);
        uint256 amountNeeded = QUOTER.quoteExactOutputSingle(
            address(USDC),
            address(WETH),
            FEE,
            requiredEth - amount1ToBorrow,
            0
        );
        uint256 amountIn = amountNeeded + amountNeeded / 1e6 - amount0ToBorrow; // 1e-6 tolerance
        uint256 eps = requiredEth / 1e5; // 1e-5 tolerance

        _borrowToLong(SWAPPER, address(USDC), _tokenId, amountIn, amount0ToBorrow, borrowerLiquidity);

        uint256 usdcSwapperBalanceAfter = USDC.balanceOf(SWAPPER);
        uint256 wethPlatformBalanceAfter = WETH.balanceOf(address(particlePositionManager));

        assertEq(usdcSwapperBalanceAfter, 0);
        assertApproxEqAbs(requiredEth, wethPlatformBalanceAfter, eps);
    }

    function testBaseOpenShortPosition() public {
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        (uint256 requiredUsdc, ) = particleInfoReader.getRequiredCollateral(borrowerLiquidity, _tickLower, _tickUpper);
        uint256 amountNeeded = QUOTER.quoteExactOutputSingle(
            address(WETH),
            address(USDC),
            FEE,
            requiredUsdc - amount0ToBorrow,
            0
        );
        uint256 amountIn = amountNeeded + amountNeeded / 1e6 - amount1ToBorrow; // 1e-6 tolerance
        uint256 eps = requiredUsdc / 1e5; // 1e-5 tolerance

        _borrowToShort(SWAPPER, address(WETH), _tokenId, amountIn, amount1ToBorrow, borrowerLiquidity);

        uint256 wethSwapperBalanceAfter = WETH.balanceOf(SWAPPER);
        uint256 usdcPlatformBalanceAfter = USDC.balanceOf(address(particlePositionManager));

        assertEq(wethSwapperBalanceAfter, 0);
        assertApproxEqAbs(requiredUsdc, usdcPlatformBalanceAfter, eps);
    }

    function testBorrowToLongMaxAmount() public {
        _borrowerLiquidityPorition = 1;
        testBaseOpenLongPosition();
    }

    function testBorrowToShortMaxAmount() public {
        _borrowerLiquidityPorition = 1;
        testBaseOpenShortPosition();
    }

    function testCannotOverSpendByDepositingLess() public {
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        (, uint256 requiredEth) = particleInfoReader.getRequiredCollateral(borrowerLiquidity, _tickLower, _tickUpper);
        uint256 amountNeeded = QUOTER.quoteExactOutputSingle(
            address(USDC),
            address(WETH),
            FEE,
            requiredEth - amount1ToBorrow,
            0
        );
        uint256 amountIn = amountNeeded - amount0ToBorrow;
        ///@dev detailed derivation in Base.t.sol's _borrowToLong
        amountIn += (amountNeeded * FEE_FACTOR) / (BASIS_POINT - FEE_FACTOR);
        amountIn -= 1; // insufficient margin in

        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, amountIn);
        vm.stopPrank();

        // get swap data
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountNeeded,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), amountIn);
        vm.expectRevert(abi.encodeWithSelector(Errors.OverSpend.selector));
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: _tokenId,
                marginFrom: amountIn,
                marginTo: 0,
                amountSwap: amountNeeded,
                liquidity: borrowerLiquidity,
                tokenFromPremiumPortionMin: 0,
                tokenToPremiumPortionMin: 0,
                marginPremiumRatio: type(uint8).max,
                zeroForOne: true,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testCannotOverBorrow() public {
        vm.startPrank(SWAPPER);
        vm.expectRevert(); ///@dev no need to top up SWAPPER, because liquidity borrowing is the first step to revert
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: _tokenId,
                marginFrom: 0,
                marginTo: 0,
                amountSwap: 0,
                liquidity: _liquidity + 1,
                tokenFromPremiumPortionMin: 0,
                tokenToPremiumPortionMin: 0,
                marginPremiumRatio: type(uint8).max,
                zeroForOne: true,
                data: new bytes(0)
            })
        );
        vm.stopPrank();
    }

    function testCannotUnderLeverageByDepositingTooMuch() public {
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        (uint256 requiredUsdc, uint256 requiredEth) = particleInfoReader.getRequiredCollateral(
            borrowerLiquidity,
            _tickLower,
            _tickUpper
        );
        uint256 amountNeeded = QUOTER.quoteExactOutputSingle(
            address(USDC),
            address(WETH),
            FEE,
            requiredEth - amount1ToBorrow,
            0
        );
        amountNeeded += amountNeeded / 10000; // 0.01% tolerance

        uint256 amountIn = amountNeeded - amount0ToBorrow;
        ///@dev detailed derivation in Base.t.sol's _borrowToLong
        amountIn += (amountNeeded * FEE_FACTOR) / (BASIS_POINT - FEE_FACTOR);

        // get swap data
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountNeeded,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        // now add too much more margin in
        ///@dev we need to add amount m, such that m * (1 - f / b) > uint24.max, where f = FEE_FACTOR, b = BASIS_POINT
        ///     so m = (uint24.max * b) / (b - f), and the b cancels with the b in original calculation's denominator
        amountIn += (requiredUsdc * (uint256(type(uint24).max) + 2)) / (BASIS_POINT - FEE_FACTOR);

        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, amountIn);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), amountIn);
        vm.expectRevert(abi.encodeWithSelector(Errors.Overflow.selector));
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: _tokenId,
                marginFrom: amountIn, // this deposit is too much, should fail
                marginTo: 0,
                amountSwap: amountNeeded,
                liquidity: borrowerLiquidity,
                tokenFromPremiumPortionMin: 0,
                tokenToPremiumPortionMin: 0,
                marginPremiumRatio: type(uint8).max,
                zeroForOne: true,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testOpenLongWithTargetToken() public {
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        uint256 amountSwapped = QUOTER.quoteExactInputSingle(address(USDC), address(WETH), FEE, amount0ToBorrow, 0);
        (, uint256 requiredEth) = particleInfoReader.getRequiredCollateral(borrowerLiquidity, _tickLower, _tickUpper);

        _directLong(
            SWAPPER,
            address(WETH),
            _tokenId,
            requiredEth - amount1ToBorrow - amountSwapped + 1 gwei, // 1 gewi tolerance
            amount0ToBorrow,
            borrowerLiquidity
        );

        uint256 wethPlatformBalanceAfter = WETH.balanceOf(address(particlePositionManager));
        assertApproxEqAbs(requiredEth, wethPlatformBalanceAfter, requiredEth / 1e6); // 1e-6 tolerance
    }

    function testOpenShortWithTargetToken() public {
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        uint256 amountSwapped = QUOTER.quoteExactInputSingle(address(WETH), address(USDC), FEE, amount1ToBorrow, 0);
        (uint256 requiredUsdc, ) = particleInfoReader.getRequiredCollateral(borrowerLiquidity, _tickLower, _tickUpper);

        _directShort(
            SWAPPER,
            address(USDC),
            _tokenId,
            requiredUsdc - amount0ToBorrow - amountSwapped + 100, // 0.0001 tolerance
            amount1ToBorrow,
            borrowerLiquidity
        );

        uint256 usdcPlatformBalanceAfter = USDC.balanceOf(address(particlePositionManager));
        assertApproxEqAbs(requiredUsdc, usdcPlatformBalanceAfter, requiredUsdc / 1e6); // 1e-6 tolerance
    }

    function testBaseOpenLongPositionOutOfRange() public {
        _setupUpperOutOfRange();
        testBaseOpenLongPosition();
    }

    function testBorrowToLongMaxAmountOutOfRange() public {
        _borrowerLiquidityPorition = 1;
        testBaseOpenLongPositionOutOfRange();
    }

    function testOpenLongWithTargetTokenOutOfRange() public {
        _setupUpperOutOfRange();
        testOpenLongWithTargetToken();
    }

    function testBaseOpenShortPositionOutOfRange() public {
        _setupLowerOutOfRange();
        testBaseOpenShortPosition();
    }

    function testBorrowToShortMaxAmountOutOfRange() public {
        _borrowerLiquidityPorition = 1;
        testBaseOpenShortPositionOutOfRange();
    }

    function testOpenShortWithTargetTokenOutOfRange() public {
        _setupLowerOutOfRange();
        testOpenShortWithTargetToken();
    }

    function testCannotSwapToOtherRecipient() public {
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        (, uint256 requiredEth) = particleInfoReader.getRequiredCollateral(borrowerLiquidity, _tickLower, _tickUpper);
        uint256 amountNeeded = QUOTER.quoteExactOutputSingle(
            address(USDC),
            address(WETH),
            FEE,
            requiredEth - amount1ToBorrow,
            0
        );
        uint256 amountIn = amountNeeded - amount0ToBorrow;
        ///@dev detailed derivation in Base.t.sol's _borrowToLong
        amountIn += (amountNeeded * FEE_FACTOR) / (BASIS_POINT - FEE_FACTOR);

        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, amountIn);
        vm.stopPrank();

        // get swap data
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: FEE,
            recipient: SWAPPER, // cannot swap to other recipient
            deadline: block.timestamp,
            amountIn: amountNeeded,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), amountIn);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientSwap.selector));
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: _tokenId,
                marginFrom: amountIn,
                marginTo: 0,
                amountSwap: amountNeeded,
                liquidity: borrowerLiquidity,
                tokenFromPremiumPortionMin: 0,
                tokenToPremiumPortionMin: 0,
                marginPremiumRatio: type(uint8).max,
                zeroForOne: true,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testCannotOpenWithInsufficientPremium() public {
        uint128 borrowerLiquidity = _liquidity / _borrowerLiquidityPorition;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtRatioX96,
            _sqrtRatioAX96,
            _sqrtRatioBX96,
            borrowerLiquidity
        );
        (, uint256 requiredEth) = particleInfoReader.getRequiredCollateral(borrowerLiquidity, _tickLower, _tickUpper);
        uint256 amountNeeded = QUOTER.quoteExactOutputSingle(
            address(USDC),
            address(WETH),
            FEE,
            requiredEth - amount1ToBorrow,
            0
        );
        uint256 amountIn = amountNeeded + amountNeeded / 1e6 - amount0ToBorrow; // 1e-6 tolerance

        uint160 currentPrice = particleInfoReader.getCurrentPrice(address(USDC), address(WETH), FEE);
        uint256 amountSwap = amountIn + amount0ToBorrow;

        // get swap data
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountIn + amount0ToBorrow,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice - currentPrice / SLIPPAGE_FACTOR
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        // pay for fee
        ///@dev see base.t.sol
        amountIn += (amountSwap * FEE_FACTOR) / (BASIS_POINT - FEE_FACTOR);

        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, amountIn);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), amountIn);
        vm.expectRevert(abi.encodeWithSelector(Errors.InsufficientPremium.selector));
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: _tokenId,
                marginFrom: amountIn,
                marginTo: 0,
                amountSwap: amountSwap,
                liquidity: borrowerLiquidity,
                tokenFromPremiumPortionMin: 1, // insufficient premium here
                tokenToPremiumPortionMin: 1, // insufficient premium here
                marginPremiumRatio: type(uint8).max,
                zeroForOne: true,
                data: data
            })
        );
        vm.stopPrank();
    }

    function testDirectLongAdminCanWithdrawTreasury() public {
        testOpenLongWithTargetToken();
        uint256 fee = USDC.balanceOf(address(particlePositionManager));
        vm.startPrank(ADMIN);
        particlePositionManager.withdrawTreasury(address(USDC), ADMIN);
        assertEq(USDC.balanceOf(address(ADMIN)), (fee * TREASURY_RATE) / BASIS_POINT);
        assertGt(fee, 0);
        vm.stopPrank();
    }

    function testDirectShortAdminCanWithdrawTreasury() public {
        testOpenShortWithTargetToken();
        uint256 fee = WETH.balanceOf(address(particlePositionManager));
        vm.startPrank(ADMIN);
        particlePositionManager.withdrawTreasury(address(WETH), ADMIN);
        assertEq(WETH.balanceOf(address(ADMIN)), (fee * TREASURY_RATE) / BASIS_POINT);
        assertGt(fee, 0);
        vm.stopPrank();
    }
}
