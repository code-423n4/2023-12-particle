// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "../lib/forge-std/src/Test.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {IUniswapV3Factory} from "../lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IQuoter} from "../lib/v3-periphery/contracts/interfaces/IQuoter.sol";
import {ISwapRouter} from "../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {TransferHelper} from "../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {INonfungiblePositionManager} from "../contracts/interfaces/INonfungiblePositionManager.sol";
import {Lien} from "../contracts/libraries/Lien.sol";
import {DataStruct} from "../contracts/libraries/Structs.sol";
import {ParticlePositionManager} from "../contracts/protocol/ParticlePositionManager.sol";
import {ParticleInfoReader} from "../contracts/protocol/ParticleInfoReader.sol";

address constant USDC_WHALE = 0xD54f502e184B6B739d7D27a6410a67dc462D69c8; // dydx
address constant DAI_WHALE = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7; // 3pool
address constant WETH_WAHLE = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e; // Aave
address constant UNI_ROUTER_ADDR = 0xE592427A0AEce92De3Edee1F18E0157C05861564; ///@dev uniswap router for testing, 1inch aggregator for production
address constant UNI_POSITION_MANAGER_ADDR = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
address constant UNI_FACTORY_ADDR = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

contract ParticlePositionManagerTestBase is Test {
    using Lien for mapping(bytes32 => Lien.Info);

    IERC20 public constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    uint256 public constant USDC_AMOUNT = 50000000 * 1e6;
    uint256 public constant DAI_AMOUNT = 50000000 * 1e18;
    uint256 public constant WETH_AMOUNT = 50000 * 1e18;
    address payable public constant ADMIN = payable(address(0x4269));
    address payable public constant LP = payable(address(0x1001));
    address payable public constant SWAPPER = payable(address(0x1002));
    address payable public constant WHALE = payable(address(0x6666));
    IQuoter public constant QUOTER = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    int24 public constant TICK_SPACING = 60;
    uint256 public constant BASIS_POINT = 1_000_000;
    uint24 public constant FEE = 3000; // uniswap swap fee
    uint256 public constant FEE_FACTOR = 500; // leveraged trading fee
    int24 public constant MIN_TICK = -887272;
    int24 public constant MAX_TICK = -MIN_TICK;
    uint160 public constant SLIPPAGE_FACTOR = 200; // 0.5% price impact
    uint128 public constant LIQUIDATION_REWARD_FACTOR = 50_000;
    uint256 public constant LOAN_TERM = 7 days;
    uint256 public constant TREASURY_RATE = 500_000;
    address public constant UNI_POSITION_MANAGER = UNI_POSITION_MANAGER_ADDR;
    INonfungiblePositionManager public nonfungiblePositionManager = INonfungiblePositionManager(UNI_POSITION_MANAGER);
    IUniswapV3Factory public uniswapV3Factory = IUniswapV3Factory(UNI_FACTORY_ADDR);
    ParticlePositionManager public particlePositionManager;
    ParticleInfoReader public particleInfoReader;

    function setUp() public virtual {
        vm.startPrank(ADMIN);
        ParticlePositionManager particlePositionManagerImpl = new ParticlePositionManager();
        ERC1967Proxy particlePositionManagerProxy = new ERC1967Proxy(address(particlePositionManagerImpl), "");
        particlePositionManager = ParticlePositionManager(payable(address(particlePositionManagerProxy)));
        particlePositionManager.initialize(
            UNI_ROUTER_ADDR,
            FEE_FACTOR,
            LIQUIDATION_REWARD_FACTOR,
            LOAN_TERM,
            TREASURY_RATE
        );
        ParticleInfoReader particleInfoReaderImpl = new ParticleInfoReader();
        ERC1967Proxy particleInfoReaderProxy = new ERC1967Proxy(address(particleInfoReaderImpl), "");
        particleInfoReader = ParticleInfoReader(payable(address(particleInfoReaderProxy)));
        particleInfoReader.initialize(address(particlePositionManager));
        vm.stopPrank();

        vm.prank(WETH_WAHLE);
        WETH.transfer(WHALE, WETH_AMOUNT);
        vm.prank(USDC_WHALE);
        USDC.transfer(WHALE, USDC_AMOUNT);
        vm.prank(DAI_WHALE);
        DAI.transfer(WHALE, DAI_AMOUNT);
    }

    function _swap(address swapper, address tokenIn, address tokenOut, uint24 fee, uint256 amount) internal {
        vm.startPrank(swapper);
        TransferHelper.safeApprove(tokenIn, UNI_ROUTER_ADDR, amount);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: swapper,
            deadline: block.timestamp,
            amountIn: amount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        ISwapRouter(UNI_ROUTER_ADDR).exactInputSingle(params);
        vm.stopPrank();
    }

    function _mint(
        address lp,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 tokenId, uint128 liquidity, uint256 amount0Minted, uint256 amount1Minted) {
        vm.startPrank(WHALE);
        IERC20(token0).transfer(lp, amount0);
        IERC20(token1).transfer(lp, amount1);
        vm.stopPrank();
        vm.startPrank(lp);
        TransferHelper.safeApprove(token0, address(particlePositionManager), amount0);
        TransferHelper.safeApprove(token1, address(particlePositionManager), amount1);
        (tokenId, liquidity, amount0Minted, amount1Minted) = particlePositionManager.mint(
            DataStruct.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0ToMint: amount0,
                amount1ToMint: amount1,
                amount0Min: 0,
                amount1Min: 0
            })
        );
        vm.stopPrank();
    }

    function _mintNative(
        address lp,
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 tokenId, uint128 liquidity, uint256 amount0Minted, uint256 amount1Minted) {
        vm.startPrank(WHALE);
        IERC20(token0).transfer(lp, amount0);
        IERC20(token1).transfer(lp, amount1);
        vm.stopPrank();
        vm.startPrank(lp);
        TransferHelper.safeApprove(token0, UNI_POSITION_MANAGER, amount0);
        TransferHelper.safeApprove(token1, UNI_POSITION_MANAGER, amount1);
        (tokenId, liquidity, amount0Minted, amount1Minted) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: block.timestamp
            })
        );
        vm.stopPrank();
    }

    function _borrowToLong(
        address swapper,
        address tokenFrom,
        uint256 tokenId,
        uint256 amountFrom,
        uint256 amountBorrowed,
        uint128 liquidity
    ) internal {
        (, , address token0, address token1, uint24 fee, , , , , , , ) = nonfungiblePositionManager.positions(tokenId);
        uint160 currentPrice = particleInfoReader.getCurrentPrice(token0, token1, fee);
        uint256 amountSwap = amountFrom + amountBorrowed;

        // get swap data
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: token0,
            tokenOut: token1,
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountSwap,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice - currentPrice / SLIPPAGE_FACTOR
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        // pay for fee
        ///@dev (amountFrom + upFrontFee + amountBorrowed) * (1 - fee / basis) = amountFrom + amountBorrowed
        ///     where fee is FEE_FACTOR and basis is BASIS_POINT.
        ///     Now let amount = amountFrom + amountBorrowed, we have
        ///     (amount + upFrontFee) * (1 - fee / basis) = amount, and so
        ///     upFrontFee = amount / (1 - fee / basis) * fee / basis = amount * fee / (basis - fee)
        amountFrom += (amountSwap * FEE_FACTOR) / (BASIS_POINT - FEE_FACTOR);

        vm.startPrank(WHALE);
        IERC20(tokenFrom).transfer(swapper, amountFrom);
        vm.stopPrank();

        vm.startPrank(swapper);
        TransferHelper.safeApprove(tokenFrom, address(particlePositionManager), amountFrom);
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: tokenId,
                marginFrom: amountFrom,
                marginTo: 0,
                amountSwap: amountSwap,
                liquidity: liquidity,
                tokenFromPremiumPortionMin: 0,
                tokenToPremiumPortionMin: 0,
                marginPremiumRatio: type(uint8).max,
                zeroForOne: true,
                data: data
            })
        );
        vm.stopPrank();
    }

    function _directLong(
        address swapper,
        address tokenTo,
        uint256 tokenId,
        uint256 amountTo,
        uint256 amountBorrowed,
        uint128 liquidity
    ) internal {
        (, , address token0, address token1, uint24 fee, , , , , , , ) = nonfungiblePositionManager.positions(tokenId);
        uint160 currentPrice = particleInfoReader.getCurrentPrice(token0, token1, fee);

        // get swap data
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: token0,
            tokenOut: token1,
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountBorrowed,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice - currentPrice / SLIPPAGE_FACTOR
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        // pay for fee
        ///@dev (amountBorrowed + upFrontFee) * (1 - fee / basis) = amountBorrowed
        ///     where fee is FEE_FACTOR and basis is BASIS_POINT, so we have
        ///     upFrontFee = amountBorrowed / (1 - fee / basis) - amountBorrowed
        ///                = amountBorrowed * basis / (basis - fee) - amountBorrowed
        uint256 feeFrom = (amountBorrowed * BASIS_POINT) / (BASIS_POINT - FEE_FACTOR) - amountBorrowed;

        vm.startPrank(WHALE);
        IERC20(tokenTo).transfer(swapper, amountTo);
        IERC20(token0).transfer(swapper, feeFrom);
        vm.stopPrank();

        vm.startPrank(swapper);
        TransferHelper.safeApprove(tokenTo, address(particlePositionManager), amountTo);
        TransferHelper.safeApprove(token0, address(particlePositionManager), feeFrom);
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: tokenId,
                marginFrom: feeFrom,
                marginTo: amountTo,
                amountSwap: amountBorrowed,
                liquidity: liquidity,
                tokenFromPremiumPortionMin: 0,
                tokenToPremiumPortionMin: 0,
                marginPremiumRatio: type(uint8).max,
                zeroForOne: true,
                data: data
            })
        );
        vm.stopPrank();
    }

    function _borrowToShort(
        address swapper,
        address tokenFrom,
        uint256 tokenId,
        uint256 amountFrom,
        uint256 amountBorrowed,
        uint128 liquidity
    ) internal {
        (, , address token0, address token1, uint24 fee, , , , , , , ) = nonfungiblePositionManager.positions(tokenId);
        uint160 currentPrice = particleInfoReader.getCurrentPrice(token0, token1, fee);
        uint256 amountSwap = amountBorrowed + amountFrom;

        // get swap data
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: token1,
            tokenOut: token0,
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountSwap,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice + currentPrice / SLIPPAGE_FACTOR
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        // pay for fee
        ///@dev amount / (1 - fee/basis) * fee/basis = amount * fee / (basis - fee), where fee is FEE_FACTOR
        ///     detailed derivation see borrowToLong
        amountFrom += (amountSwap * FEE_FACTOR) / (BASIS_POINT - FEE_FACTOR);

        vm.startPrank(WHALE);
        IERC20(tokenFrom).transfer(swapper, amountFrom);
        vm.stopPrank();

        vm.startPrank(swapper);
        TransferHelper.safeApprove(tokenFrom, address(particlePositionManager), amountFrom);
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: tokenId,
                marginFrom: amountFrom,
                marginTo: 0,
                amountSwap: amountSwap,
                liquidity: liquidity,
                tokenFromPremiumPortionMin: 0,
                tokenToPremiumPortionMin: 0,
                marginPremiumRatio: type(uint8).max,
                zeroForOne: false,
                data: data
            })
        );
        vm.stopPrank();
    }

    function _directShort(
        address swapper,
        address tokenTo,
        uint256 tokenId,
        uint256 amountTo,
        uint256 amountBorrowed,
        uint128 liquidity
    ) internal {
        (, , address token0, address token1, uint24 fee, , , , , , , ) = nonfungiblePositionManager.positions(tokenId);
        uint160 currentPrice = particleInfoReader.getCurrentPrice(token0, token1, fee);

        // get swap data
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: token1,
            tokenOut: token0,
            fee: FEE,
            recipient: address(particlePositionManager),
            deadline: block.timestamp,
            amountIn: amountBorrowed,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: currentPrice + currentPrice / SLIPPAGE_FACTOR
        });
        bytes memory data = abi.encodeWithSelector(ISwapRouter.exactInputSingle.selector, params);

        // pay for fee
        ///@dev upFrontFee = amountBorrowed * basis / (basis - fee) - amountBorrowed
        ///     detailed derivation see directLong
        uint256 feeFrom = (amountBorrowed * BASIS_POINT) / (BASIS_POINT - FEE_FACTOR) - amountBorrowed;

        vm.startPrank(WHALE);
        IERC20(tokenTo).transfer(swapper, amountTo);
        IERC20(token1).transfer(swapper, feeFrom);
        vm.stopPrank();

        vm.startPrank(swapper);
        TransferHelper.safeApprove(tokenTo, address(particlePositionManager), amountTo);
        TransferHelper.safeApprove(token1, address(particlePositionManager), feeFrom);
        particlePositionManager.openPosition(
            DataStruct.OpenPositionParams({
                tokenId: tokenId,
                marginFrom: feeFrom,
                marginTo: amountTo,
                amountSwap: amountBorrowed,
                liquidity: liquidity,
                tokenFromPremiumPortionMin: 0,
                tokenToPremiumPortionMin: 0,
                marginPremiumRatio: type(uint8).max,
                zeroForOne: false,
                data: data
            })
        );
        vm.stopPrank();
    }
}
