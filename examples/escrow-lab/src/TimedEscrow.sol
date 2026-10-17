// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice One payment. Buyer may release before the deadline;
/// anyone may trigger a refund to the buyer at or after it.
/// @dev Teaching example: no delivery verification or dispute resolution.
contract TimedEscrow {
    enum State { AwaitingPayment, Funded, Released, Refunded }

    address public immutable buyer;
    address payable public immutable seller;
    uint256 public immutable price;
    uint256 public immutable deadline;
    State public state;

    error InvalidConfig();
    error Unauthorized();
    error InvalidState();
    error WrongAmount();
    error DeadlinePassed();
    error DeadlineNotReached();
    error TransferFailed();

    event Funded(address indexed buyer, uint256 amount);
    event Released(address indexed seller, uint256 amount);
    event Refunded(address indexed buyer, uint256 amount);

    constructor(
        address buyer_,
        address payable seller_,
        uint256 price_,
        uint256 deadline_
    ) {
        if (
            buyer_ == address(0) || seller_ == address(0)
                || buyer_ == seller_ || price_ == 0
                || deadline_ <= block.timestamp
        ) revert InvalidConfig();
        buyer = buyer_;
        seller = seller_;
        price = price_;
        deadline = deadline_;
    }

    function fund() external payable {
        if (msg.sender != buyer) revert Unauthorized();
        if (state != State.AwaitingPayment) revert InvalidState();
        if (block.timestamp >= deadline) revert DeadlinePassed();
        if (msg.value != price) revert WrongAmount();

        state = State.Funded;
        emit Funded(msg.sender, msg.value);
    }

    function release() external {
        if (msg.sender != buyer) revert Unauthorized();
        if (state != State.Funded) revert InvalidState();
        if (block.timestamp >= deadline) revert DeadlinePassed();

        state = State.Released;
        (bool ok,) = seller.call{value: price}("");
        if (!ok) revert TransferFailed();
        emit Released(seller, price);
    }

    function refund() external {
        if (state != State.Funded) revert InvalidState();
        if (block.timestamp < deadline) revert DeadlineNotReached();

        state = State.Refunded;
        (bool ok,) = payable(buyer).call{value: price}("");
        if (!ok) revert TransferFailed();
        emit Refunded(buyer, price);
    }
}
