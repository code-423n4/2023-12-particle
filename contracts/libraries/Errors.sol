// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library Errors {
    error Unauthorized();
    error RecordEmpty();
    error SwapFailed();
    error OverSpend();
    error OverRefund();
    error Overflow();
    error RenewalDisabled();
    error InsufficientSwap();
    error InsufficientBorrow();
    error InsufficientRepay();
    error InsufficientPremium();
    error LiquidationNotMet();
    error InvalidRecipient();
    error InvalidValue();
}
