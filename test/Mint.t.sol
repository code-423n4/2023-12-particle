// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721} from "../lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IERC721} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {IUniswapV3Pool} from "../lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {DataStruct} from "../contracts/libraries/Structs.sol";
import {ParticlePositionManagerTestBase} from "./Base.t.sol";

contract MintTest is ParticlePositionManagerTestBase {
    uint256 public constant MINT_AMOUNT_0 = 1000 * 1e6;
    uint256 public constant MINT_AMOUNT_1 = 1 ether;
    int24 public constant TICK_STEP = 420;

    function testMintInRange() public {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (uint256 tokenId, , , ) = _mint(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            tickLower,
            tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );

        uint256 token0BalanceAfter = USDC.balanceOf(LP);
        uint256 token1BalanceAfter = WETH.balanceOf(LP);

        (address lp, , , ) = particlePositionManager.lps(tokenId);
        assertEq(lp, LP);
        assertEq(IERC721(UNI_POSITION_MANAGER).ownerOf(tokenId), address(particlePositionManager));

        assertGt(MINT_AMOUNT_0, token0BalanceAfter);
        assertGt(MINT_AMOUNT_1, token1BalanceAfter);
    }

    function testMintOutRangeToken0() public {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick - TICK_STEP * 2) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (uint256 tokenId, , , ) = _mint(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            tickLower,
            tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );

        uint256 token0BalanceAfter = USDC.balanceOf(LP);
        uint256 token1BalanceAfter = WETH.balanceOf(LP);

        (address lp, , , ) = particlePositionManager.lps(tokenId);
        assertEq(lp, LP);
        assertEq(IERC721(UNI_POSITION_MANAGER).ownerOf(tokenId), address(particlePositionManager));

        assertEq(token0BalanceAfter, MINT_AMOUNT_0); // all USDC unused
        assertApproxEqAbs(token1BalanceAfter, 0, 1 gwei); // all WETH used, 1 gwei dust tolerance
    }

    function testMintOutRangeToken1() public {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick + TICK_STEP * 2) / TICK_SPACING) * TICK_SPACING;

        (uint256 tokenId, , , ) = _mint(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            tickLower,
            tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );

        uint256 token0BalanceAfter = USDC.balanceOf(LP);
        uint256 token1BalanceAfter = WETH.balanceOf(LP);

        (address lp, , , ) = particlePositionManager.lps(tokenId);
        assertEq(lp, LP);
        assertEq(IERC721(UNI_POSITION_MANAGER).ownerOf(tokenId), address(particlePositionManager));

        assertApproxEqAbs(token0BalanceAfter, 0, 100); // all USDC unused, 0.0001 dust tolerance
        assertEq(token1BalanceAfter, MINT_AMOUNT_1); // all WETH used
    }

    function testMintNativeInRange() public {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (uint256 tokenId, , , ) = _mintNative(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            tickLower,
            tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );

        uint256 token0BalanceAfter = USDC.balanceOf(LP);
        uint256 token1BalanceAfter = WETH.balanceOf(LP);

        assertEq(IERC721(UNI_POSITION_MANAGER).ownerOf(tokenId), LP);
        (address lp, , , ) = particlePositionManager.lps(tokenId);
        assertEq(lp, address(0));

        assertGt(MINT_AMOUNT_0, token0BalanceAfter);
        assertGt(MINT_AMOUNT_1, token1BalanceAfter);
    }

    function testTransferPositionNft() public {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (uint256 tokenId, , , ) = _mintNative(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            tickLower,
            tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );

        vm.startPrank(LP);
        (address lp, , , ) = particlePositionManager.lps(tokenId);
        assertEq(lp, address(0));
        /// @dev must use safe transfer from to trigger onERC721Received
        IERC721(UNI_POSITION_MANAGER).safeTransferFrom(LP, address(particlePositionManager), tokenId);
        (lp, , , ) = particlePositionManager.lps(tokenId);
        assertEq(lp, LP);
        vm.stopPrank();
    }

    function testTransferNonPositionNftNoTokenId() public {
        FreeMintNft nft = new FreeMintNft("free", "mint");
        nft.mint(LP, 42);
        vm.startPrank(LP);
        IERC721(nft).safeTransferFrom(LP, address(particlePositionManager), 42);
        (address lp, , , ) = particlePositionManager.lps(42);
        assertEq(lp, address(0));
        vm.stopPrank();
    }

    function testMintWithSlippageAboveShouldPass() public {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (, , uint256 amount0Minted, uint256 amount1Minted) = _mintNative(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            tickLower,
            tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );

        vm.startPrank(WHALE);
        IERC20(USDC).transfer(LP, MINT_AMOUNT_0);
        IERC20(WETH).transfer(LP, MINT_AMOUNT_1);
        vm.stopPrank();

        vm.startPrank(LP);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), MINT_AMOUNT_0);
        TransferHelper.safeApprove(address(WETH), address(particlePositionManager), MINT_AMOUNT_1);
        particlePositionManager.mint(
            DataStruct.MintParams({
                token0: address(USDC),
                token1: address(WETH),
                fee: FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0ToMint: MINT_AMOUNT_0,
                amount1ToMint: MINT_AMOUNT_1,
                amount0Min: amount0Minted,
                amount1Min: amount1Minted
            })
        );
        vm.stopPrank();
    }

    function testMintWithSlippageProtected() public {
        IUniswapV3Pool pool = IUniswapV3Pool(uniswapV3Factory.getPool(address(USDC), address(WETH), FEE));
        (, int24 tick, , , , , ) = pool.slot0();

        int24 tickLower = ((tick - TICK_STEP) / TICK_SPACING) * TICK_SPACING;
        int24 tickUpper = ((tick + TICK_STEP) / TICK_SPACING) * TICK_SPACING;

        (, , uint256 amount0Minted, uint256 amount1Minted) = _mintNative(
            LP,
            address(USDC),
            address(WETH),
            FEE,
            tickLower,
            tickUpper,
            MINT_AMOUNT_0,
            MINT_AMOUNT_1
        );

        vm.startPrank(WHALE);
        IERC20(USDC).transfer(LP, MINT_AMOUNT_0);
        IERC20(WETH).transfer(LP, MINT_AMOUNT_1);
        vm.stopPrank();

        vm.startPrank(LP);
        TransferHelper.safeApprove(address(USDC), address(particlePositionManager), MINT_AMOUNT_0);
        TransferHelper.safeApprove(address(WETH), address(particlePositionManager), MINT_AMOUNT_1);
        vm.expectRevert("Price slippage check");
        particlePositionManager.mint(
            DataStruct.MintParams({
                token0: address(USDC),
                token1: address(WETH),
                fee: FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0ToMint: MINT_AMOUNT_0,
                amount1ToMint: MINT_AMOUNT_1,
                amount0Min: amount0Minted + 1,
                amount1Min: amount1Minted + 1
            })
        );
        vm.stopPrank();
    }
}

contract FreeMintNft is ERC721 {
    // solhint-disable-next-line no-empty-blocks
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }
}
