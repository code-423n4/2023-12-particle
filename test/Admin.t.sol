// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "../contracts/libraries/Errors.sol";
import {ParticlePositionManagerTestBase} from "./Base.t.sol";

contract AdminTest is ParticlePositionManagerTestBase {
    address private constant _ONE_INCH_AGGREGATOR = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    function testAdminCanUpdateDexAggregator() public {
        vm.startPrank(ADMIN);
        particlePositionManager.updateDexAggregator(_ONE_INCH_AGGREGATOR);
        assertEq(particlePositionManager.DEX_AGGREGATOR(), _ONE_INCH_AGGREGATOR);
        vm.stopPrank();
    }

    function testNonAdminCannotUpdateDexAggregator() public {
        vm.startPrank(WHALE);
        vm.expectRevert("Ownable: caller is not the owner");
        particlePositionManager.updateDexAggregator(_ONE_INCH_AGGREGATOR);
        vm.stopPrank();
    }

    function testAdminCanUpdateLiquidationRewardFactor() public {
        vm.startPrank(ADMIN);
        particlePositionManager.updateLiquidationRewardFactor(888);
        assertEq(particlePositionManager.LIQUIDATION_REWARD_FACTOR(), 888);
        vm.stopPrank();
    }

    function testAdminCannotOverUpdateLiquidationRewardFactor() public {
        vm.startPrank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidValue.selector));
        particlePositionManager.updateLiquidationRewardFactor(100_001);
        vm.stopPrank();
    }

    function testNonAdminCannotUpdateLiquidationRewardFactor() public {
        vm.startPrank(WHALE);
        vm.expectRevert("Ownable: caller is not the owner");
        particlePositionManager.updateLiquidationRewardFactor(42);
        vm.stopPrank();
    }

    function testAdminCanUpdateFeeFactor() public {
        vm.startPrank(ADMIN);
        particlePositionManager.updateFeeFactor(4);
        assertEq(particlePositionManager.FEE_FACTOR(), 4);
        vm.stopPrank();
    }

    function testAdminCannotOverUpdateFeeFactor() public {
        vm.startPrank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidValue.selector));
        particlePositionManager.updateFeeFactor(1_001);
        vm.stopPrank();
    }

    function testNonAdminCannotUpdateFeeFactor() public {
        vm.startPrank(WHALE);
        vm.expectRevert("Ownable: caller is not the owner");
        particlePositionManager.updateFeeFactor(4);
        vm.stopPrank();
    }

    function testAdminCanUpdateLoanTerm() public {
        vm.startPrank(ADMIN);
        particlePositionManager.updateLoanTerm(8 days);
        assertEq(particlePositionManager.LOAN_TERM(), 8 days);
        vm.stopPrank();
    }

    function testAdminCannotOverUpdateLoanTerm() public {
        vm.startPrank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidValue.selector));
        particlePositionManager.updateLoanTerm(30 days + 1 seconds);
        vm.stopPrank();
    }

    function testNonAdminCannotUpdateLoanTerm() public {
        vm.startPrank(WHALE);
        vm.expectRevert("Ownable: caller is not the owner");
        particlePositionManager.updateLoanTerm(8 days);
        vm.stopPrank();
    }

    function testAdminCanUpdateTreasuryRate() public {
        vm.startPrank(ADMIN);
        particlePositionManager.updateTreasuryRate(4269);
        vm.stopPrank();
    }

    function testAdminCannotOverUpdateTreasuryRate() public {
        vm.startPrank(ADMIN);
        vm.expectRevert(abi.encodeWithSelector(Errors.InvalidValue.selector));
        particlePositionManager.updateTreasuryRate(500_001);
        vm.stopPrank();
    }

    function testNonAdminCannotUpdateTreasuryRate() public {
        vm.startPrank(WHALE);
        vm.expectRevert("Ownable: caller is not the owner");
        particlePositionManager.updateTreasuryRate(4269);
        vm.stopPrank();
    }

    ///@dev other withdraw treasury tests are in open/close position test
    function testNonAdminCannotWithdrawTreasury() public {
        vm.startPrank(WHALE);
        vm.expectRevert("Ownable: caller is not the owner");
        particlePositionManager.withdrawTreasury(address(USDC), WHALE);
        vm.stopPrank();
    }

    function testAdminCanUpdateInfoReader() public {
        vm.startPrank(ADMIN);
        particleInfoReader.updateParticleAddress(address(0x42));
        assertEq(particleInfoReader.PARTICLE_POSITION_MANAGER_ADDR(), address(0x42));
        vm.stopPrank();
    }

    function testNonAdminCannotUpdateInfoReader() public {
        vm.startPrank(WHALE);
        vm.expectRevert("Ownable: caller is not the owner");
        particleInfoReader.updateParticleAddress(address(0x42));
        vm.stopPrank();
    }
}
