// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TransferHelper} from "../../lib/v3-periphery/contracts/libraries/TransferHelper.sol";
import {Errors} from "./Errors.sol";
import {Base} from "./Base.sol";

/// @title Swap Position
/// @notice Represents a direct swap's token address and locked amount
library SwapPosition {
    struct Info {
        address token;
        uint256 amount;
    }

    /*=============================================================
                               Swap Logic
    ==============================================================*/

    /**
     * @notice Act as a transient router to swap at most `amountFrom` of `tokenFrom` for at least `amountToMinimum` of `tokenTo`
     * @param tokenFrom address of token to swap from
     * @param tokenTo address of token to swap to
     * @param amountFrom amount of tokenFrom to swap
     * @param amountToMinimum minimum amount of tokenTo to receive
     * @param dexAggregator address of DEX aggregator to perform swapping
     * @param data calldata bytes to pass into DEX aggregator to perform swapping
     * @return amountSpent amount of tokenFrom spent
     * @return amountReceived amount of tokenTo received
     */
    function swap(
        address tokenFrom,
        address tokenTo,
        uint256 amountFrom,
        uint256 amountToMinimum,
        address dexAggregator,
        bytes calldata data
    ) internal returns (uint256 amountSpent, uint256 amountReceived) {
        TransferHelper.safeTransferFrom(tokenFrom, msg.sender, address(this), amountFrom);
        (amountSpent, amountReceived) = Base.swap(tokenFrom, tokenTo, amountFrom, amountToMinimum, dexAggregator, data);
        TransferHelper.safeTransfer(tokenTo, msg.sender, amountReceived);
        Base.refund(msg.sender, tokenFrom, amountFrom, amountSpent);
    }
}
