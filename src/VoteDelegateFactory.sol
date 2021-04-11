// VoteDelegateFactory - create and keep record of delegats
pragma solidity 0.6.12;

import "./VoteDelegate.sol";

contract VoteDelegateFactory {
    DSChief public immutable chief;
    mapping(address => VoteDelegate) public delegates;

    event VoteDelegateCreated(
        address indexed delegate,
        address indexed voteDelegate
    );

    event VoteDelegateDestroyed(
        address indexed delegate,
        address indexed voteDelegate
    );

    constructor(address chief_) public {
        chief = DSChief(chief_);
    }

    function isDelegate(address guy) public view returns (bool) {
        return (address(delegates[guy]) != address(0x0));
    }

    function create() public returns (VoteDelegate voteDelegate) {
        require(!isDelegate(msg.sender), "this address is already a delegate");

        voteDelegate = new VoteDelegate(chief, msg.sender, address(this));
        delegates[msg.sender] = voteDelegate;
        emit VoteDelegateCreated(msg.sender, address(voteDelegate));
    }

    function destroy() public {
        require(isDelegate(msg.sender), "No VoteDelegate found");

        delete delegates[msg.sender];
        emit VoteDelegateDestroyed(msg.sender, address(voteDelegate));
    }
}
