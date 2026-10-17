// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {TimedEscrow} from "../src/TimedEscrow.sol";

contract RejectEther {
    receive() external payable { revert("reject"); }
}

contract ReenteringBuyer {
    TimedEscrow public escrow;
    bool public attempted;
    bool public reentered;

    function setEscrow(TimedEscrow escrow_) external { escrow = escrow_; }

    receive() external payable {
        attempted = true;
        try escrow.refund() { reentered = true; } catch {}
    }
}

contract TimedEscrowTest is Test {
    TimedEscrow escrow;
    address buyer = makeAddr("buyer");
    address payable seller = payable(makeAddr("seller"));
    address stranger = makeAddr("stranger");
    uint256 constant PRICE = 1 ether;

    function setUp() public {
        vm.warp(1_000_000);
        vm.deal(buyer, 200 ether);
        vm.deal(stranger, 2 ether);
        escrow = new TimedEscrow(buyer, seller, PRICE, block.timestamp + 1 days);
    }

    function _fund() internal {
        vm.prank(buyer);
        escrow.fund{value: PRICE}();
    }

    function test_FundAndRelease() public {
        _fund();
        vm.prank(buyer);
        escrow.release();
        assertEq(uint256(escrow.state()), uint256(TimedEscrow.State.Released));
        assertEq(seller.balance, PRICE);
        assertEq(address(escrow).balance, 0);
    }

    function test_OnlyBuyerCanFund() public {
        vm.prank(stranger);
        vm.expectRevert(TimedEscrow.Unauthorized.selector);
        escrow.fund{value: PRICE}();
    }

    function test_RejectWrongAmount() public {
        vm.prank(buyer);
        vm.expectRevert(TimedEscrow.WrongAmount.selector);
        escrow.fund{value: PRICE - 1}();
    }

    function test_CannotFundTwice() public {
        _fund();
        vm.prank(buyer);
        vm.expectRevert(TimedEscrow.InvalidState.selector);
        escrow.fund{value: PRICE}();
    }

    function test_OnlyBuyerCanRelease() public {
        _fund();
        vm.prank(stranger);
        vm.expectRevert(TimedEscrow.Unauthorized.selector);
        escrow.release();
    }

    function test_CannotReleaseBeforeFunding() public {
        vm.prank(buyer);
        vm.expectRevert(TimedEscrow.InvalidState.selector);
        escrow.release();
    }

    function test_CannotRefundBeforeDeadline() public {
        _fund();
        vm.warp(escrow.deadline() - 1);
        vm.expectRevert(TimedEscrow.DeadlineNotReached.selector);
        escrow.refund();
    }

    function test_AnyoneCanRefundAtDeadline() public {
        _fund();
        uint256 beforeBalance = buyer.balance;
        vm.warp(escrow.deadline());
        vm.prank(stranger);
        escrow.refund();
        assertEq(buyer.balance, beforeBalance + PRICE);
        assertEq(uint256(escrow.state()), uint256(TimedEscrow.State.Refunded));
    }

    function test_CannotReleaseAtDeadline() public {
        _fund();
        vm.warp(escrow.deadline());
        vm.prank(buyer);
        vm.expectRevert(TimedEscrow.DeadlinePassed.selector);
        escrow.release();
    }

    function test_CannotFundAtDeadline() public {
        vm.warp(escrow.deadline());
        vm.prank(buyer);
        vm.expectRevert(TimedEscrow.DeadlinePassed.selector);
        escrow.fund{value: PRICE}();
    }

    function test_CannotPayTwice() public {
        _fund();
        vm.prank(buyer);
        escrow.release();
        vm.prank(buyer);
        vm.expectRevert(TimedEscrow.InvalidState.selector);
        escrow.release();
        vm.warp(escrow.deadline());
        vm.expectRevert(TimedEscrow.InvalidState.selector);
        escrow.refund();
    }

    function test_FailedTransferRollsBackState() public {
        RejectEther receiver = new RejectEther();
        TimedEscrow blocked = new TimedEscrow(
            buyer, payable(address(receiver)), PRICE, block.timestamp + 1 days
        );
        vm.prank(buyer);
        blocked.fund{value: PRICE}();
        vm.prank(buyer);
        vm.expectRevert(TimedEscrow.TransferFailed.selector);
        blocked.release();
        assertEq(uint256(blocked.state()), uint256(TimedEscrow.State.Funded));
        assertEq(address(blocked).balance, PRICE);
    }

    function test_RefundCannotReenter() public {
        ReenteringBuyer receiver = new ReenteringBuyer();
        TimedEscrow guarded = new TimedEscrow(
            address(receiver), seller, PRICE, block.timestamp + 1 days
        );
        receiver.setEscrow(guarded);
        vm.deal(address(receiver), PRICE);
        vm.prank(address(receiver));
        guarded.fund{value: PRICE}();
        vm.warp(guarded.deadline());
        guarded.refund();
        assertTrue(receiver.attempted());
        assertFalse(receiver.reentered());
        assertEq(address(receiver).balance, PRICE);
    }

    function test_RejectInvalidConfiguration() public {
        vm.expectRevert(TimedEscrow.InvalidConfig.selector);
        new TimedEscrow(address(0), seller, PRICE, block.timestamp + 1 days);
    }

    function testFuzz_ReleasePreservesAmount(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, 100 ether);
        TimedEscrow sample = new TimedEscrow(
            buyer, seller, amount, block.timestamp + 1 days
        );
        uint256 sellerBefore = seller.balance;
        vm.prank(buyer);
        sample.fund{value: amount}();
        vm.prank(buyer);
        sample.release();
        assertEq(seller.balance - sellerBefore, amount);
        assertEq(address(sample).balance, 0);
    }
}
