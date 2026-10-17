// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TimedEscrow} from "../src/TimedEscrow.sol";

contract EscrowHandler is Test {
    TimedEscrow public escrow;

    constructor(TimedEscrow escrow_) { escrow = escrow_; }

    function fund() external {
        if (escrow.state() != TimedEscrow.State.AwaitingPayment) return;
        if (block.timestamp >= escrow.deadline()) return;
        address payer = escrow.buyer();
        uint256 amount = escrow.price();
        vm.prank(payer);
        escrow.fund{value: amount}();
    }

    function release() external {
        if (escrow.state() != TimedEscrow.State.Funded) return;
        if (block.timestamp >= escrow.deadline()) return;
        vm.prank(escrow.buyer());
        escrow.release();
    }

    function refund() external {
        if (escrow.state() != TimedEscrow.State.Funded) return;
        if (block.timestamp < escrow.deadline()) return;
        escrow.refund();
    }

    function advance(uint32 seconds_) external {
        vm.warp(block.timestamp + bound(uint256(seconds_), 0, 2 days));
    }
}

contract TimedEscrowInvariantTest is StdInvariant, Test {
    TimedEscrow escrow;
    address buyer = makeAddr("buyer");
    address payable seller = payable(makeAddr("seller"));
    uint256 constant PRICE = 1 ether;

    function setUp() public {
        vm.deal(buyer, PRICE);
        escrow = new TimedEscrow(buyer, seller, PRICE, block.timestamp + 1 days);
        targetContract(address(new EscrowHandler(escrow)));
    }

    function invariant_ConservesFunds() public view {
        assertEq(buyer.balance + seller.balance + address(escrow).balance, PRICE);
    }

    function invariant_FundedObligationIsCovered() public view {
        if (escrow.state() == TimedEscrow.State.Funded) {
            assertGe(address(escrow).balance, PRICE);
        }
    }
}
