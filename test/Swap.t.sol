// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IUniswapV3Pool} from "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {TickMath} from "../contracts/libraries/TickMath.sol";
import {Errors} from "../contracts/libraries/Errors.sol";
import {LiquidityAmounts} from "../contracts/libraries/LiquidityAmounts.sol";
import {DataStruct} from "../contracts/libraries/Structs.sol";
import {ParticlePositionManagerTestBase} from "./Base.t.sol";

contract SwapTest is ParticlePositionManagerTestBase {
    uint256 public constant MINT_AMOUNT_0 = 15000 * 1e6;
    uint256 public constant MINT_AMOUNT_1 = 10 ether;
    uint256 public constant USDC_AMOUNT_IN = 1000 * 1e6;
    uint96 public constant SWAP_ID = 0;
    uint128 public constant BORROWER_LIQUIDITY_PORTION = 20;
    int24 public constant TICK_STEP = 200;

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

    function _swap() internal returns (uint256 amount0, uint256 amount1) {
        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, USDC_AMOUNT_IN);
        vm.stopPrank();

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: USDC_AMOUNT_IN,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), USDC_AMOUNT_IN);
        (amount0, amount1) = particlePositionManager.swap(address(USDC), address(WETH), USDC_AMOUNT_IN, 0, data);
        vm.stopPrank();
    }

    function testTransientSwapAmount() public {
        (uint256 amount0, uint256 amount1) = _swap();
        assertEq(USDC.balanceOf(SWAPPER), USDC_AMOUNT_IN - amount0);
        assertEq(WETH.balanceOf(SWAPPER), amount1);
        assertEq(USDC.balanceOf(address(particlePositionManager)), 0);
        assertEq(WETH.balanceOf(address(particlePositionManager)), 0);
    }

    function testTransientSwapCannotOverspendParam() public {
        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), USDC_AMOUNT_IN);
        vm.expectRevert(bytes("STF"));
        // overspend here
        particlePositionManager.swap(address(USDC), address(WETH), USDC_AMOUNT_IN + 1, 0, new bytes(0));
        vm.stopPrank();
    }

    function testTransientSwapCannotOverspendData() public {
        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, USDC_AMOUNT_IN);
        vm.stopPrank();

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(USDC),
            tokenOut: address(WETH),
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: USDC_AMOUNT_IN + 1, // overspend
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        vm.startPrank(SWAPPER);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), USDC_AMOUNT_IN);
        vm.expectRevert(abi.encodeWithSelector(Errors.SwapFailed.selector));
        particlePositionManager.swap(address(USDC), address(WETH), USDC_AMOUNT_IN, 0, data);
        vm.stopPrank();
    }

    function testComposePositionAmountIsCorrect() public {
        (uint160 sqrtRatioX96, , , , , , ) = _pool.slot0();
        uint128 borrowerLiquidity = _liquidity / BORROWER_LIQUIDITY_PORTION;
        (uint256 amount0ToBorrow, uint256 amount1ToBorrow) = LiquidityAmounts.getAmountsForLiquidity(
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
        uint256 amountSwap = QUOTER.quoteExactOutputSingle(
            address(USDC),
            address(WETH),
            FEE,
            requiredCollateral - amount1ToBorrow,
            0
        );
        uint256 amountIn = amountSwap - amount0ToBorrow;
        uint256 eps = amountIn / 1000; // 0.1% tolerance
        amountIn += eps;

        // pay for fee
        /// @dev details check Base.t.sol
        uint256 amountInWithFee = amountIn +
            ((amountIn + USDC_AMOUNT_IN + amount0ToBorrow) * FEE_FACTOR) /
            (BASIS_POINT - FEE_FACTOR);

        DataStruct.OpenPositionParams memory openPositionParams = DataStruct.OpenPositionParams({
            tokenId: _tokenId,
            marginFrom: amountInWithFee + USDC_AMOUNT_IN,
            marginTo: 0,
            amountSwap: amountSwap + USDC_AMOUNT_IN,
            liquidity: borrowerLiquidity,
            tokenFromPremiumPortionMin: 0,
            tokenToPremiumPortionMin: 0,
            marginPremiumRatio: type(uint8).max,
            zeroForOne: true,
            data: abi.encodeWithSelector(
                ISwapRouter.exactInputSingle.selector,
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: address(USDC),
                    tokenOut: address(WETH),
                    fee: FEE,
                    recipient: address(particlePositionManager),
                    deadline: block.timestamp,
                    amountIn: amountSwap + USDC_AMOUNT_IN, // swap both leveraged and regular swap
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            )
        });

        vm.startPrank(WHALE);
        USDC.transfer(SWAPPER, USDC_AMOUNT_IN + amountInWithFee);
        vm.stopPrank();

        vm.startPrank(SWAPPER);
        // approve both leveraged and regular swap
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), USDC_AMOUNT_IN + amountInWithFee);
        particlePositionManager.openPosition(openPositionParams);

        // TODO: confirm amount spent, premium portion, amount locked in contract are correct
        vm.stopPrank();
    }
}
