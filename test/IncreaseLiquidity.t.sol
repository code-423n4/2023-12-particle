// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IUniswapV3Pool} from "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {Errors} from "../contracts/libraries/Errors.sol";
import {ParticlePositionManagerTestBase} from "./Base.t.sol";

contract IncreaseLiquidityTest is ParticlePositionManagerTestBase {
    uint256 public constant MINT_AMOUNT_0 = 1000 * 1e6;
    uint256 public constant MINT_AMOUNT_1 = 1 ether;
    uint256 public constant INCREASE_AMOUNT_0 = 2000 * 1e6;
    uint256 public constant INCREASE_AMOUNT_1 = 2 ether;
    int24 public constant TICK_STEP = 420;

    uint256 internal _tokenId;

    function setUp() public override {
        super.setUp();

        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (_tokenId, , , ) = _mint(
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

    function testIncreaseLiquidity() public {
        (, , , , , , , uint128 liquidityBefore, , , , ) = nonfungiblePositionManager.positions(_tokenId);

        vm.startPrank(WHALE);
        USDC.transfer(LP, INCREASE_AMOUNT_0);
        WETH.transfer(LP, INCREASE_AMOUNT_1);
        vm.stopPrank();

        vm.startPrank(LP);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), INCREASE_AMOUNT_0);
        TransferHelper.safeApprove(address(WETH), address(particlePositionManager), INCREASE_AMOUNT_1);

        (uint128 liquidityAdded, , ) = particlePositionManager.increaseLiquidity(
            _tokenId,
            INCREASE_AMOUNT_0,
            INCREASE_AMOUNT_1
        );

        (, , , , , , , uint128 liquidityAfter, , , , ) = nonfungiblePositionManager.positions(_tokenId);

        assertEq(liquidityAfter, liquidityBefore + liquidityAdded);

        vm.stopPrank();
    }

    function testCannotIncreaseNonOwnerLiquidity() public {
        address payable lp2 = payable(address(0x1003));

        vm.startPrank(WHALE);
        USDC.transfer(lp2, INCREASE_AMOUNT_0);
        WETH.transfer(lp2, INCREASE_AMOUNT_1);
        vm.stopPrank();

        vm.startPrank(lp2);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), INCREASE_AMOUNT_0);
        TransferHelper.safeApprove(address(WETH), address(particlePositionManager), INCREASE_AMOUNT_1);

        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector));
        particlePositionManager.increaseLiquidity(_tokenId, INCREASE_AMOUNT_0, INCREASE_AMOUNT_1);
        vm.stopPrank();
    }
}
