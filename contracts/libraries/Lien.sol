// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title Lien
/// @notice Represents a open position's locked premium, liquidity and owed tokwn amounts
/// @dev Only stores the minimally required information to close/liquidate a position
library Lien {
    struct Info {
        uint40 tokenId;
        uint128 liquidity;
        uint24 token0PremiumPortion;
        uint24 token1PremiumPortion;
        uint32 startTime;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        bool zeroForOne;
    }

    /**
     * @notice Getter for a lien's info
     * @param self The mapping containing all liens
     * @param lienKey The key of the lien (borrower, lienId)
     * @return lien The lien info struct
     */
    function getInfo(mapping(bytes32 => Info) storage self, bytes32 lienKey) internal view returns (Info storage lien) {
        lien = self[lienKey];
    }

    /**
     * @notice Getter for a lien's liquidity
     * @param self The mapping containing all liens
     * @param lienKey The key of the lien (borrower, lienId)
     * @return liquidity The amount of liquidity locked in the lien
     */
    function getLiquidity(
        mapping(bytes32 => Info) storage self,
        bytes32 lienKey
    ) internal view returns (uint128 liquidity) {
        liquidity = self[lienKey].liquidity;
    }

    /**
     * @notice Update a lien's preminum amounts
     * @dev Caller of this function should ensure lien is renewable by checking cutoff time
     * @param self The mapping containing all liens
     * @param lienKey The key of the lien (borrower, lienId)
     * @param token0PremiumPortion The amount of token0 premium porition to update to
     * @param token1PremiumPortion The amount of token1 premium porition to update to
     * @dev the premium amount (lifetime premium in a position) is capped at uint24.MAX
     */
    function updatePremium(
        mapping(bytes32 => Info) storage self,
        bytes32 lienKey,
        uint24 token0PremiumPortion,
        uint24 token1PremiumPortion
    ) internal {
        self[lienKey].token0PremiumPortion = token0PremiumPortion;
        self[lienKey].token1PremiumPortion = token1PremiumPortion;
        self[lienKey].startTime = uint32(block.timestamp);
    }
}
