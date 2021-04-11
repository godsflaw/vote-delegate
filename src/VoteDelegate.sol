// VoteDelegate - delegate your vote
pragma solidity 0.6.12;

import "ds-math/math.sol";
import "ds-token/token.sol";
import "ds-chief/chief.sol";

contract VoteDelegate is DSMath {
    mapping(address => uint256) public delegators;
    address public immutable delegate;
    DSToken public immutable gov;
    DSToken public immutable iou;
    DSChief public immutable chief;

    constructor(address _chief, address _delegate) public {
        chief = DSChief(_chief);
        delegate = _delegate;

        gov = DSChief(_chief).GOV();
        iou = DSChief(_chief).IOU();

        gov.approve(_chief, uint256(-1));
        iou.approve(_chief, uint256(-1));
    }

    modifier delegate_auth() {
        require(msg.sender == delegate, "Sender must be delegate");
        _;
    }

    function lock(uint256 wad) public {
        delegators[msg.sender] = add(delegators[msg.sender], wad);
        gov.pull(msg.sender, wad);
        chief.lock(wad);
        iou.push(msg.sender, wad);
    }

    function free(uint256 wad) public {
        delegators[msg.sender] = sub(delegators[msg.sender], wad);
        iou.pull(msg.sender, wad);
        chief.free(wad);
        gov.push(msg.sender, wad);
    }

    function vote(address[] memory yays) public delegate_auth returns (bytes32) {
        return chief.vote(yays);
    }

    function vote(bytes32 slate) public delegate_auth {
        chief.vote(slate);
    }
}
