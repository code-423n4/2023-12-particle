// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {DataStruct} from "../libraries/Structs.sol";

interface IParticlePositionManager {
    /*==============================================================
                               Event Logs
    ==============================================================*/

    event OpenPosition(address borrower, uint256 lienId, uint256 positionAmount);
    event ClosePosition(address borrower, uint256 tokenId, uint256 token0Repaid, uint256 token1Repaid);
    event LiquidatePosition(address borrower, uint256 tokenId, uint256 token0Repaid, uint256 token1Repaid);
    event AddPremium(address borrower, uint256 lienId, uint128 premium0, uint128 premium1);
    event UpdateDexAggregator(address dexAggregator);
    event UpdateLiquidationRewardFactor(uint128 liquidationRewardFactor);
    event UpdateFeeFactor(uint256 feeFactor);
    event UpdateLoanTerm(uint256 loanTerm);
    event UpdateTreasuryRate(uint256 treasuryRate);
    event WithdrawTreasury(address token, address recipient, uint256 amount);

    /*==============================================================
                       Liquidity Provision Logic
    ==============================================================*/

    ///@dev inheritdoc LiquidityPosition.mint
    function mint(
        DataStruct.MintParams calldata params
    ) external returns (uint256 tokenId, uint128 liquidity, uint256 amount0Minted, uint256 amount1Minted);

    /*==============================================================
                       Liquidity Management Logic
    ==============================================================*/

    ///@dev inheritdoc LiquidityPosition.increaseLiquidity
    function increaseLiquidity(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) external returns (uint128 liquidity, uint256 amount0Added, uint256 amount1Added);

    ///@dev inheritdoc LiquidityPosition.decreaseLiquidity
    function decreaseLiquidity(
        uint256 tokenId,
        uint128 liquidity
    ) external returns (uint256 amount0Decreased, uint256 amount1Decreased);

    ///@dev inheritdoc LiquidityPosition.collectLiquidity
    function collectLiquidity(uint256 tokenId) external returns (uint256 amount0Collected, uint256 amount1Collected);

    ///@dev inheritdoc LiquidityPosition.reclaimLiquidity
    function reclaimLiquidity(uint256 tokenId) external;

    /*=============================================================
                              Trading Logic
    ==============================================================*/

    /**
     * @notice Basic open position of a leveraged swap
     * @dev The passed-in collateral amountIn and liquidity are best effort simulated from frontend
     * @param params.tokenId tokenId of the liquidity position NFT
     * @param params.marginFrom amount of collateral + premium for the token to be swapped from
     * @param params.marginTo amount of collateral + premium for the token to be swapped to
     * @param params.amountSwap amount of tokenFrom to actually swap (will be margin + borrowed - premium)
     * @param params.liquidity amount of liquidity to borrow out
     * @param params.tokenFromPremiumPortionMin minimum premium of tokenFrom as portion of tokenFrom collateral
     * @param params.tokenToPremiumPortionMin minimum premium of tokenTo as portion of tokenTo collateral
     * @param params.marginPremiumRatio @dev only for frontend display purpose, all leftover amounts are premiums
     * @param params.zeroForOne direction of the swap
     * @param params.data calldata bytes to pass into DEX aggregator to perform swapping
     * @return lienId ID for the newly created lien
     * @return collateralTo amount of target token locked in the position (deposited, borrowed and swapped)
     */
    function openPosition(
        DataStruct.OpenPositionParams calldata params
    ) external returns (uint96 lienId, uint256 collateralTo);

    /**
     * @notice Basic close position of a leveraged swap
     * @dev The passed-in amount to return/gain are best effort simulated from frontend
     * @param params.lienId the ID for the existing loan
     * @param params.amountSwap total amount of tokenFrom (the tokenTo in openPosition) to swap back
     * @param params.data calldata bytes to pass into DEX aggregator to perform swapping
     */
    function closePosition(DataStruct.ClosePositionParams calldata params) external;

    /**
     * @notice Basic liquidation position of a leveraged swap
     * @dev The passed-in amount to pay for LP is best effort simulated from frontend
     * @param params.lienId the ID for the existing loan
     * @param params.amountSwap total amount of tokenFrom (the tokenTo in openPosition) to swap back
     * @param params.data calldata bytes to pass into DEX aggregator to perform swapping
     * @param borrower the address
     */
    function liquidatePosition(DataStruct.ClosePositionParams calldata params, address borrower) external;

    /**
     * @notice Add premium to a lien
     * @param lienId ID for the existing lien
     * @param premium0 amount of token0 premium to add
     * @param premium1 amount of token1 premium to add
     */
    function addPremium(uint96 lienId, uint128 premium0, uint128 premium1) external;

    /*=============================================================
                              Vanilla Swap
    ==============================================================*/

    ///@dev inheritdoc SwapPosition.swap
    function swap(
        address token0,
        address token1,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /*=============================================================
                              Admin Logic
    ==============================================================*/

    /**
     * @notice Update the DEX aggregator address
     * @param dexAggregator address of the new DEX aggregator
     */
    function updateDexAggregator(address dexAggregator) external;

    /**
     * @notice Update liquidation reward factor
     * @param liquidationRewardFactor new liquidation reward factor
     */
    function updateLiquidationRewardFactor(uint128 liquidationRewardFactor) external;

    /**
     * @notice Update fee factor
     * @param feeFactor new fee factor
     */
    function updateFeeFactor(uint256 feeFactor) external;

    /**
     * @notice Update loan term
     * @param loanTerm new loan term
     */
    function updateLoanTerm(uint256 loanTerm) external;

    /**
     * @notice Update treasury rate
     * @param treasuryRate new treasury rate
     */
    function updateTreasuryRate(uint256 treasuryRate) external;

    /**
     * @notice Withdraw from treasury
     * @param token address to token to withdraw
     * @param recipient receiver of the token in treasury
     */
    function withdrawTreasury(address token, address recipient) external;
}
