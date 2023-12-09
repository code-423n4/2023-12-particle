// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721Receiver} from "../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {Multicall} from "../../lib/openzeppelin-contracts/contracts/utils/Multicall.sol";
import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Ownable2StepUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";

import {IParticlePositionManager} from "../interfaces/IParticlePositionManager.sol";
import {Base} from "../libraries/Base.sol";
import {LiquidityPosition} from "../libraries/LiquidityPosition.sol";
import {Lien} from "../libraries/Lien.sol";
import {SwapPosition} from "../libraries/SwapPosition.sol";
import {DataStruct, DataCache} from "../libraries/Structs.sol";
import {Errors} from "../libraries/Errors.sol";

contract ParticlePositionManager is
    IParticlePositionManager,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    IERC721Receiver,
    ReentrancyGuard,
    Multicall
{
    using LiquidityPosition for mapping(uint256 => LiquidityPosition.Info);
    using Lien for mapping(bytes32 => Lien.Info);
    using SwapPosition for mapping(bytes32 => SwapPosition.Info);

    /* Constants */
    uint256 private constant _TREASURY_RATE_MAX = 500_000;
    uint256 private constant _FEE_FACTOR_MAX = 1_000;
    uint128 private constant _LIQUIDATION_REWARD_FACTOR_MAX = 100_000;
    uint256 private constant _LOAN_TERM_MAX = 30 days;

    /* Variables */
    uint96 private _nextRecordId; ///@dev used for both lien and swap
    uint256 private _treasuryRate;
    // solhint-disable var-name-mixedcase
    address public DEX_AGGREGATOR;
    uint256 public FEE_FACTOR;
    uint128 public LIQUIDATION_REWARD_FACTOR;
    uint256 public LOAN_TERM;
    // solhint-enable var-name-mixedcase

    /* Storage */
    mapping(uint256 => LiquidityPosition.Info) public lps; ///@dev tokenId => liquidity position
    mapping(bytes32 => Lien.Info) public liens; ///@dev (address, lienId) => lien
    mapping(address => uint256) private _treasury; ///@dev address => amount

    // required by openzeppelin UUPS module
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address dexAggregator,
        uint256 feeFactor,
        uint128 liquidationRewardFactor,
        uint256 loanTerm,
        uint256 treasuryRate
    ) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        DEX_AGGREGATOR = dexAggregator;
        FEE_FACTOR = feeFactor;
        LIQUIDATION_REWARD_FACTOR = liquidationRewardFactor;
        LOAN_TERM = loanTerm;
        _treasuryRate = treasuryRate;
    }

    /*==============================================================
                        Liquidity Provision Logic
    ==============================================================*/

    /// @inheritdoc IParticlePositionManager
    function mint(
        DataStruct.MintParams calldata params
    )
        external
        override
        nonReentrant
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0Minted, uint256 amount1Minted)
    {
        (tokenId, liquidity, amount0Minted, amount1Minted) = lps.mint(params);
    }

    /**
     * @notice Receiver function upon ERC721 LP position transfer
     * @dev LP must use safeTransferFrom to trigger onERC721Received
     * @param from the address which previously owned the NFT
     * @param tokenId the NFT identifier which is being transferred
     */
    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        if (msg.sender == Base.UNI_POSITION_MANAGER_ADDR) {
            // matched with Uniswap v3 position NFTs
            lps[tokenId] = LiquidityPosition.Info({owner: from, renewalCutoffTime: 0, token0Owed: 0, token1Owed: 0});
            (, , , , , , , uint128 liquidity, , , , ) = Base.UNI_POSITION_MANAGER.positions(tokenId);
            emit LiquidityPosition.SupplyLiquidity(tokenId, from, liquidity);
        }
        return this.onERC721Received.selector;
    }

    /*==============================================================
                       Liquidity Management Logic
    ==============================================================*/

    /// @inheritdoc IParticlePositionManager
    function increaseLiquidity(
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1
    ) external override nonReentrant returns (uint128 liquidity, uint256 amount0Added, uint256 amount1Added) {
        (liquidity, amount0Added, amount1Added) = lps.increaseLiquidity(tokenId, amount0, amount1);
    }

    /// @inheritdoc IParticlePositionManager
    function decreaseLiquidity(
        uint256 tokenId,
        uint128 liquidity
    ) external override nonReentrant returns (uint256 amount0Decreased, uint256 amount1Decreased) {
        (amount0Decreased, amount1Decreased) = lps.decreaseLiquidity(tokenId, liquidity);
    }

    /// @inheritdoc IParticlePositionManager
    function collectLiquidity(
        uint256 tokenId
    ) external override nonReentrant returns (uint256 amount0Collected, uint256 amount1Collected) {
        (amount0Collected, amount1Collected) = lps.collectLiquidity(tokenId);
    }

    /// @inheritdoc IParticlePositionManager
    function reclaimLiquidity(uint256 tokenId) external override nonReentrant {
        lps.reclaimLiquidity(tokenId);
    }

    /*=============================================================
                             Open Position
    ==============================================================*/

    /// @inheritdoc IParticlePositionManager
    function openPosition(
        DataStruct.OpenPositionParams calldata params
    ) public override nonReentrant returns (uint96 lienId, uint256 collateralTo) {
        if (params.liquidity == 0) revert Errors.InsufficientBorrow();

        // local cache to avoid stack too deep
        DataCache.OpenPositionCache memory cache;

        // prepare data for swap
        (
            cache.tokenFrom,
            cache.tokenTo,
            cache.feeGrowthInside0LastX128,
            cache.feeGrowthInside1LastX128,
            cache.collateralFrom,
            collateralTo
        ) = Base.prepareLeverage(params.tokenId, params.liquidity, params.zeroForOne);

        // decrease liquidity from LP position, pull the amount to this contract
        (cache.amountFromBorrowed, cache.amountToBorrowed) = LiquidityPosition.decreaseLiquidity(
            params.tokenId,
            params.liquidity
        );
        LiquidityPosition.collectLiquidity(
            params.tokenId,
            uint128(cache.amountFromBorrowed),
            uint128(cache.amountToBorrowed),
            address(this)
        );
        if (!params.zeroForOne)
            (cache.amountFromBorrowed, cache.amountToBorrowed) = (cache.amountToBorrowed, cache.amountFromBorrowed);

        // transfer in enough collateral
        if (params.marginFrom > 0) {
            TransferHelper.safeTransferFrom(cache.tokenFrom, msg.sender, address(this), params.marginFrom);
        }
        if (params.marginTo > 0) {
            TransferHelper.safeTransferFrom(cache.tokenTo, msg.sender, address(this), params.marginTo);
        }

        // pay for fee
        if (FEE_FACTOR > 0) {
            cache.feeAmount = ((params.marginFrom + cache.amountFromBorrowed) * FEE_FACTOR) / Base.BASIS_POINT;
            cache.treasuryAmount = (cache.feeAmount * _treasuryRate) / Base.BASIS_POINT;
            _treasury[cache.tokenFrom] += cache.treasuryAmount;
            if (params.zeroForOne) {
                lps.addTokensOwed(params.tokenId, uint128(cache.feeAmount - cache.treasuryAmount), 0);
            } else {
                lps.addTokensOwed(params.tokenId, 0, uint128(cache.feeAmount - cache.treasuryAmount));
            }
        }

        // cannot swap more than available amount
        if (params.amountSwap > params.marginFrom + cache.amountFromBorrowed - cache.feeAmount)
            revert Errors.OverSpend();

        // swap to meet the collateral requirement
        (cache.amountSpent, cache.amountReceived) = Base.swap(
            cache.tokenFrom,
            cache.tokenTo,
            params.amountSwap,
            collateralTo - cache.amountToBorrowed - params.marginTo, // amount needed to meet requirement
            DEX_AGGREGATOR,
            params.data
        );

        // leftover amounts from the collateral are now premiums, and ensure enough premium is stored
        if (params.zeroForOne) {
            cache.token0PremiumPortion = Base.uint256ToUint24(
                ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *
                    Base.BASIS_POINT) / cache.collateralFrom
            );
            cache.token1PremiumPortion = Base.uint256ToUint24(
                ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /
                    collateralTo
            );
            if (
                cache.token0PremiumPortion < params.tokenFromPremiumPortionMin ||
                cache.token1PremiumPortion < params.tokenToPremiumPortionMin
            ) revert Errors.InsufficientPremium();
        } else {
            cache.token1PremiumPortion = Base.uint256ToUint24(
                ((params.marginFrom + cache.amountFromBorrowed - cache.feeAmount - cache.amountSpent) *
                    Base.BASIS_POINT) / cache.collateralFrom
            );
            cache.token0PremiumPortion = Base.uint256ToUint24(
                ((cache.amountReceived + cache.amountToBorrowed + params.marginTo - collateralTo) * Base.BASIS_POINT) /
                    collateralTo
            );
            if (
                cache.token0PremiumPortion < params.tokenToPremiumPortionMin ||
                cache.token1PremiumPortion < params.tokenFromPremiumPortionMin
            ) revert Errors.InsufficientPremium();
        }

        // create a new lien
        liens[keccak256(abi.encodePacked(msg.sender, lienId = _nextRecordId++))] = Lien.Info({
            tokenId: uint40(params.tokenId),
            liquidity: params.liquidity,
            token0PremiumPortion: cache.token0PremiumPortion,
            token1PremiumPortion: cache.token1PremiumPortion,
            startTime: uint32(block.timestamp),
            feeGrowthInside0LastX128: cache.feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: cache.feeGrowthInside1LastX128,
            zeroForOne: params.zeroForOne
        });

        emit OpenPosition(msg.sender, lienId, collateralTo);
    }

    /*=============================================================
                             Close Position
    ==============================================================*/

    /// @inheritdoc IParticlePositionManager
    function closePosition(DataStruct.ClosePositionParams calldata params) external override nonReentrant {
        bytes32 lienKey = keccak256(abi.encodePacked(msg.sender, params.lienId));
        Lien.Info memory lien = liens.getInfo(lienKey);

        // check lien is valid
        if (lien.liquidity == 0) revert Errors.RecordEmpty();

        // delete lien from storage
        delete liens[lienKey];

        // local cache to avoid stack too deep
        DataCache.ClosePositionCache memory cache;

        // prepare data for swap back
        ///@dev the token/collateralFrom and token/collateralTo are swapped compared to openPosition
        (cache.tokenTo, cache.tokenFrom, , , cache.collateralTo, cache.collateralFrom) = Base.prepareLeverage(
            lien.tokenId,
            lien.liquidity,
            lien.zeroForOne
        );

        // get the amount of premium in the lien
        if (lien.zeroForOne) {
            (cache.tokenToPremium, cache.tokenFromPremium) = Base.getPremium(
                cache.collateralTo,
                cache.collateralFrom,
                lien.token0PremiumPortion,
                lien.token1PremiumPortion
            );
        } else {
            (cache.tokenFromPremium, cache.tokenToPremium) = Base.getPremium(
                cache.collateralFrom,
                cache.collateralTo,
                lien.token0PremiumPortion,
                lien.token1PremiumPortion
            );
        }

        // execute actual position closing
        _closePosition(params, cache, lien, msg.sender);

        emit ClosePosition(msg.sender, lien.tokenId, cache.amountFromAdd, cache.amountToAdd);
    }

    /// @inheritdoc IParticlePositionManager
    function liquidatePosition(
        DataStruct.ClosePositionParams calldata params,
        address borrower
    ) external override nonReentrant {
        bytes32 lienKey = keccak256(abi.encodePacked(borrower, params.lienId));
        Lien.Info memory lien = liens.getInfo(lienKey);

        // check lien is valid
        if (lien.liquidity == 0) revert Errors.RecordEmpty();

        // local cache to avoid stack too deep
        DataCache.ClosePositionCache memory closeCache;
        DataCache.LiquidatePositionCache memory liquidateCache;

        // get liquidation parameters
        ///@dev calculate premium outside of _closePosition to allow liquidatePosition to take reward from premium
        (
            closeCache.tokenFrom,
            closeCache.tokenTo,
            liquidateCache.tokenFromOwed,
            liquidateCache.tokenToOwed,
            closeCache.tokenFromPremium,
            closeCache.tokenToPremium,
            closeCache.collateralFrom,

        ) = Base.getOwedInfoConverted(
            DataStruct.OwedInfoParams({
                tokenId: lien.tokenId,
                liquidity: lien.liquidity,
                feeGrowthInside0LastX128: lien.feeGrowthInside0LastX128,
                feeGrowthInside1LastX128: lien.feeGrowthInside1LastX128,
                token0PremiumPortion: lien.token0PremiumPortion,
                token1PremiumPortion: lien.token1PremiumPortion
            }),
            lien.zeroForOne
        );

        // calculate liquidation reward
        liquidateCache.liquidationRewardFrom =
            ((closeCache.tokenFromPremium) * LIQUIDATION_REWARD_FACTOR) /
            uint128(Base.BASIS_POINT);
        liquidateCache.liquidationRewardTo =
            ((closeCache.tokenToPremium) * LIQUIDATION_REWARD_FACTOR) /
            uint128(Base.BASIS_POINT);
        closeCache.tokenFromPremium -= liquidateCache.liquidationRewardFrom;
        closeCache.tokenToPremium -= liquidateCache.liquidationRewardTo;

        // check for liquidation condition
        ///@dev the liquidation condition is that
        ///     (EITHER premium is not enough) OR (cutOffTime > startTime AND currentTime > startTime + LOAN_TERM)
        if (
            !((closeCache.tokenFromPremium < liquidateCache.tokenFromOwed ||
                closeCache.tokenToPremium < liquidateCache.tokenToOwed) ||
                (lien.startTime < lps.getRenewalCutoffTime(lien.tokenId) &&
                    lien.startTime + LOAN_TERM < block.timestamp))
        ) {
            revert Errors.LiquidationNotMet();
        }

        // delete lien from storage
        delete liens[lienKey];

        // execute actual position closing
        _closePosition(params, closeCache, lien, borrower);

        // reward liquidator
        TransferHelper.safeTransfer(closeCache.tokenFrom, msg.sender, liquidateCache.liquidationRewardFrom);
        TransferHelper.safeTransfer(closeCache.tokenTo, msg.sender, liquidateCache.liquidationRewardTo);

        emit LiquidatePosition(borrower, lien.tokenId, closeCache.amountFromAdd, closeCache.amountToAdd);
    }

    /**
     * @notice Internal function to close a position
     * @dev Caller must ensure either the msg.sender is borrower or liquidation condition is met
     * @param params close position parameters
     * @param cache local cache to avoid stack too deep
     * @param lien lien info
     * @param borrower borrower address
     */
    function _closePosition(
        DataStruct.ClosePositionParams calldata params,
        DataCache.ClosePositionCache memory cache,
        Lien.Info memory lien,
        address borrower
    ) internal {
        // check for overspend
        if (params.amountSwap + params.repayFrom > cache.collateralFrom + cache.tokenFromPremium)
            revert Errors.OverSpend();

        // optimistically use the input numbers to swap for repay
        (cache.amountSpent, cache.amountReceived) = Base.swap(
            cache.tokenFrom,
            cache.tokenTo,
            params.amountSwap,
            params.repayTo,
            DEX_AGGREGATOR,
            params.data
        );

        // based on borrowed liquidity, compute the required return amount
        /// @dev the from-to swapping direction is reverted compared to openPosition
        (cache.amountToAdd, cache.amountFromAdd) = Base.getRequiredRepay(lien.liquidity, lien.tokenId);
        if (!lien.zeroForOne) (cache.amountToAdd, cache.amountFromAdd) = (cache.amountFromAdd, cache.amountToAdd);

        // the liquidity to add must be no less than the declared amount
        if (cache.amountFromAdd > params.repayFrom || cache.amountToAdd > params.repayTo) {
            revert Errors.InsufficientRepay();
        }

        // add liquidity back to borrower
        if (lien.zeroForOne) {
            (cache.liquidityAdded, cache.amountToAdd, cache.amountFromAdd) = LiquidityPosition.increaseLiquidity(
                cache.tokenTo,
                cache.tokenFrom,
                lien.tokenId,
                cache.amountToAdd,
                cache.amountFromAdd
            );
        } else {
            (cache.liquidityAdded, cache.amountFromAdd, cache.amountToAdd) = LiquidityPosition.increaseLiquidity(
                cache.tokenFrom,
                cache.tokenTo,
                lien.tokenId,
                cache.amountFromAdd,
                cache.amountToAdd
            );
        }

        // obtain the position's latest FeeGrowthInside after increaseLiquidity
        (, , , , , , , , cache.feeGrowthInside0LastX128, cache.feeGrowthInside1LastX128, , ) = Base
            .UNI_POSITION_MANAGER
            .positions(lien.tokenId);

        // caculate the amounts owed since last fee collection during the borrowing period
        (cache.token0Owed, cache.token1Owed) = Base.getOwedFee(
            cache.feeGrowthInside0LastX128,
            cache.feeGrowthInside1LastX128,
            lien.feeGrowthInside0LastX128,
            lien.feeGrowthInside1LastX128,
            lien.liquidity
        );

        // calculate the the amounts owed to LP up to the premium in the lien
        // must ensure enough amount is left to pay for interest first, then send gains and fund left to borrower
        ///@dev refundWithCheck ensures actual cannot be more than expected, since amount owed to LP is in actual,
        ///     it ensures (1) on the collateralFrom part of refund, tokenOwed is covered, and (2) on the amountReceived
        ///      part, received is no less than liquidity addback + token owed.
        if (lien.zeroForOne) {
            cache.token0Owed = cache.token0Owed < cache.tokenToPremium ? cache.token0Owed : cache.tokenToPremium;
            cache.token1Owed = cache.token1Owed < cache.tokenFromPremium ? cache.token1Owed : cache.tokenFromPremium;
            Base.refundWithCheck(
                borrower,
                cache.tokenFrom,
                cache.collateralFrom + cache.tokenFromPremium,
                cache.amountSpent + cache.amountFromAdd + cache.token1Owed
            );
            Base.refundWithCheck(
                borrower,
                cache.tokenTo,
                cache.amountReceived + cache.tokenToPremium,
                cache.amountToAdd + cache.token0Owed
            );
        } else {
            cache.token0Owed = cache.token0Owed < cache.tokenFromPremium ? cache.token0Owed : cache.tokenFromPremium;
            cache.token1Owed = cache.token1Owed < cache.tokenToPremium ? cache.token1Owed : cache.tokenToPremium;
            Base.refundWithCheck(
                borrower,
                cache.tokenFrom,
                cache.collateralFrom + cache.tokenFromPremium,
                cache.amountSpent + cache.amountFromAdd + cache.token0Owed
            );
            Base.refundWithCheck(
                borrower,
                cache.tokenTo,
                cache.amountReceived + cache.tokenToPremium,
                cache.amountToAdd + cache.token1Owed
            );
        }

        // pay for interest
        lps.addTokensOwed(lien.tokenId, cache.token0Owed, cache.token1Owed);
    }

    /*=============================================================
                             Premium Logic
    ==============================================================*/

    /// @inheritdoc IParticlePositionManager
    function addPremium(uint96 lienId, uint128 premium0, uint128 premium1) external override nonReentrant {
        bytes32 lienKey = keccak256(abi.encodePacked(msg.sender, lienId));
        Lien.Info memory lien = liens.getInfo(lienKey);

        // check lien is valid
        if (lien.liquidity == 0) revert Errors.RecordEmpty();

        // check LP allows extension of this lien
        if (lps.getRenewalCutoffTime(lien.tokenId) > lien.startTime) revert Errors.RenewalDisabled();

        (, , address token0, address token1, , int24 tickLower, int24 tickUpper, , , , , ) = Base
            .UNI_POSITION_MANAGER
            .positions(lien.tokenId);
        (uint256 collateral0, uint256 collateral1) = Base.getRequiredCollateral(lien.liquidity, tickLower, tickUpper);

        (uint128 token0Premium, uint128 token1Premium) = Base.getPremium(
            collateral0,
            collateral1,
            lien.token0PremiumPortion,
            lien.token1PremiumPortion
        );

        liens.updatePremium(
            lienKey,
            uint24(((token0Premium + premium0) * Base.BASIS_POINT) / collateral0),
            uint24(((token1Premium + premium1) * Base.BASIS_POINT) / collateral1)
        );

        // transfer in added premium
        if (premium0 > 0) {
            TransferHelper.safeTransferFrom(token0, msg.sender, address(this), premium0);
        }
        if (premium1 > 0) {
            TransferHelper.safeTransferFrom(token1, msg.sender, address(this), premium1);
        }

        emit AddPremium(msg.sender, lienId, premium0, premium1);
    }

    /*=============================================================
                              Vanilla Swap
    ==============================================================*/

    /// @inheritdoc IParticlePositionManager
    function swap(
        address token0,
        address token1,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bytes calldata data
    ) external override nonReentrant returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = SwapPosition.swap(token0, token1, amountIn, amountOutMinimum, DEX_AGGREGATOR, data);
    }

    /*=============================================================
                              Admin logic
    ==============================================================*/

    /// @inheritdoc IParticlePositionManager
    function updateDexAggregator(address dexAggregator) external override onlyOwner {
        if (dexAggregator == address(0)) revert Errors.InvalidValue();
        DEX_AGGREGATOR = dexAggregator;
        emit UpdateDexAggregator(dexAggregator);
    }

    /// @inheritdoc IParticlePositionManager
    function updateLiquidationRewardFactor(uint128 liquidationRewardFactor) external override onlyOwner {
        if (liquidationRewardFactor > _LIQUIDATION_REWARD_FACTOR_MAX) revert Errors.InvalidValue();
        LIQUIDATION_REWARD_FACTOR = liquidationRewardFactor;
        emit UpdateLiquidationRewardFactor(liquidationRewardFactor);
    }

    /// @inheritdoc IParticlePositionManager
    function updateFeeFactor(uint256 feeFactor) external override onlyOwner {
        if (feeFactor > _FEE_FACTOR_MAX) revert Errors.InvalidValue();
        FEE_FACTOR = feeFactor;
        emit UpdateFeeFactor(feeFactor);
    }

    /// @inheritdoc IParticlePositionManager
    function updateLoanTerm(uint256 loanTerm) external override onlyOwner {
        if (loanTerm > _LOAN_TERM_MAX) revert Errors.InvalidValue();
        LOAN_TERM = loanTerm;
        emit UpdateLoanTerm(loanTerm);
    }

    /// @inheritdoc IParticlePositionManager
    function updateTreasuryRate(uint256 treasuryRate) external override onlyOwner {
        if (treasuryRate > _TREASURY_RATE_MAX) revert Errors.InvalidValue();
        _treasuryRate = treasuryRate;
        emit UpdateTreasuryRate(treasuryRate);
    }

    /// @inheritdoc IParticlePositionManager
    function withdrawTreasury(address token, address recipient) external override onlyOwner nonReentrant {
        uint256 withdrawAmount = _treasury[token];
        if (withdrawAmount > 0) {
            if (recipient == address(0)) {
                revert Errors.InvalidRecipient();
            }
            _treasury[token] = 0;
            TransferHelper.safeTransfer(token, recipient, withdrawAmount);
            emit WithdrawTreasury(token, recipient, withdrawAmount);
        }
    }
}
