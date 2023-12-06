// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {IUniswapV3Pool} from "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {Errors} from "../contracts/libraries/Errors.sol";
import {ParticlePositionManagerTestBase} from "./Base.t.sol";

contract DecreaseLiquidityTest is ParticlePositionManagerTestBase {
    uint256 public constant MINT_AMOUNT_0 = 1000 * 1e6;
    uint256 public constant MINT_AMOUNT_1 = 1 ether;
    uint256 public constant INCREASE_AMOUNT_0 = 2000 * 1e6;
    uint256 public constant INCREASE_AMOUNT_1 = 2 ether;
    int24 public constant TICK_STEP = 420;

    uint256 internal _tokenId;
    uint256 internal _amount0Minted;
    uint256 internal _amount1Minted;

    function setUp() public override {
        super.setUp();

        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (_tokenId, , _amount0Minted, _amount1Minted) = _mint(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            tickLower,
            tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );
    }

    function testMintDecreaseHalfLiquidity() public {
        (, , , , , , , uint128 liquidityBefore, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        uint128 liquidityToDecrease = liquidityBefore / 2;
        vm.startPrank(LP);
        particlePositionManager.decreaseLiquidity(_tokenId, liquidityToDecrease);

        (, , , , , , , uint128 liquidityAfter, , , , ) = nonfungiblePositionManager.positions(_tokenId);

        assertEq(liquidityAfter + liquidityToDecrease, liquidityBefore);

        vm.stopPrank();
    }

    function testMintDecreaseAllLiquidity() public {
        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        vm.startPrank(LP);

        uint256 usdcBalanceBefore = USDC.balanceOf(LP);
        uint256 wethBalanceBefore = WETH.balanceOf(LP);

        (uint256 amount0Decreased, uint256 amount1Decreased) = particlePositionManager.decreaseLiquidity(
            _tokenId,
            liquidity
        );
        (uint256 amount0Returned, uint256 amount1Returned) = particlePositionManager.collectLiquidity(_tokenId);

        uint256 usdcBalanceAfter = USDC.balanceOf(LP);
        uint256 wethBalanceAfter = WETH.balanceOf(LP);

        assertEq(amount0Decreased, amount0Returned);
        assertEq(amount1Decreased, amount1Returned);

        assertEq(usdcBalanceAfter - usdcBalanceBefore, amount0Returned);
        assertEq(wethBalanceAfter - wethBalanceBefore, amount1Returned);

        assertApproxEqAbs(_amount0Minted, amount0Returned, 10); // get original USDC back, 0.00001 dust tolerance
        assertApproxEqAbs(_amount1Minted, amount1Returned, 10); // get original ETH back, 10 wei tolerance

        vm.stopPrank();
    }

    function testMintIncreaseDecreaseAllLiquidity() public {
        vm.startPrank(WHALE);
        USDC.transfer(LP, INCREASE_AMOUNT_0);
        WETH.transfer(LP, INCREASE_AMOUNT_1);
        vm.stopPrank();

        vm.startPrank(LP);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), INCREASE_AMOUNT_0);
        TransferHelper.safeApprove(address(WETH), address(particlePositionManager), INCREASE_AMOUNT_1);

        (, uint256 amount0Added, uint256 amount1Added) = particlePositionManager.increaseLiquidity(
            _tokenId,
            INCREASE_AMOUNT_0,
            INCREASE_AMOUNT_1
        );

        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager.positions(_tokenId);

        uint256 usdcBalanceBefore = USDC.balanceOf(LP);
        uint256 wethBalanceBefore = WETH.balanceOf(LP);

        (uint256 amount0Decreased, uint256 amount1Decreased) = particlePositionManager.decreaseLiquidity(
            _tokenId,
            liquidity
        );
        (uint256 amount0Returned, uint256 amount1Returned) = particlePositionManager.collectLiquidity(_tokenId);

        uint256 usdcBalanceAfter = USDC.balanceOf(LP);
        uint256 wethBalanceAfter = WETH.balanceOf(LP);

        assertEq(amount0Decreased, amount0Returned);
        assertEq(amount1Decreased, amount1Returned);

        assertEq(usdcBalanceAfter - usdcBalanceBefore, amount0Returned);
        assertEq(wethBalanceAfter - wethBalanceBefore, amount1Returned);

        assertApproxEqAbs(amount0Added + _amount0Minted, amount0Returned, 10); // get original USDC back, 0.00001 dust tolerance
        assertApproxEqAbs(amount1Added + _amount1Minted, amount1Returned, 10); // get original ETH back, 10 wei tolerance
    }

    function testCannotOverDecreaseLiquidity() public {
        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        vm.startPrank(LP);
        vm.expectRevert(); // EVM revert
        particlePositionManager.decreaseLiquidity(_tokenId, liquidity + 1);
        vm.stopPrank();
    }

    function testCannotDecreaseNonOwnerLiquidity() public {
        address payable lp2 = payable(address(0x1003));

        (, , , , , , , uint128 liquidity, , , , ) = nonfungiblePositionManager.positions(_tokenId);
        vm.startPrank(lp2);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector));
        particlePositionManager.decreaseLiquidity(_tokenId, liquidity);
        vm.stopPrank();
    }

    function testCannotCollectNonOwnerLiquidity() public {
        address payable lp2 = payable(address(0x1003));
        vm.startPrank(lp2);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector));
        particlePositionManager.collectLiquidity(_tokenId);
        vm.stopPrank();
    }
}
