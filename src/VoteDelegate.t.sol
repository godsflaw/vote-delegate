pragma solidity 0.6.12;

import "ds-test/test.sol";
import "ds-token/token.sol";
import "ds-chief/chief.sol";

import "./VoteDelegate.sol";

contract Voter {
    DSChief chief;
    DSToken gov;
    DSToken iou;
    VoteDelegate public proxy;

    constructor(DSChief chief_, DSToken gov_, DSToken iou_) public {
        chief = chief_;
        gov = gov_;
        iou = iou_;
    }

    function setProxy(VoteDelegate proxy_) public {
        proxy = proxy_;
    }

    function doChiefLock(uint amt) public {
        chief.lock(amt);
    }

    function doChiefFree(uint amt) public {
        chief.free(amt);
    }

    function doTransfer(address guy, uint amt) public {
        gov.transfer(guy, amt);
    }

    function approveGov(address guy) public {
        gov.approve(guy);
    }

    function approveIou(address guy) public {
        iou.approve(guy);
    }

    function doProxyLock(uint amt) public {
        proxy.lock(amt);
    }

    function doProxyFree(uint amt) public {
        proxy.free(amt);
    }

    function doProxyFreeAll() public {
        proxy.free(proxy.delegators(address(this)));
    }

    function doProxyVote(address[] memory yays) public returns (bytes32 slate) {
        return proxy.vote(yays);
    }

    function doProxyVote(bytes32 slate) public {
        proxy.vote(slate);
    }
}

contract VoteDelegateTest is DSTest {
    uint256 constant electionSize = 3;
    address constant c1 = address(0x1);
    address constant c2 = address(0x2);
    bytes byts;

    VoteDelegate proxy;
    DSToken gov;
    DSToken iou;
    DSChief chief;

    Voter delegate;
    Voter delegator1;
    Voter delegator2;

    function setUp() public {
        gov = new DSToken("GOV");

        DSChiefFab fab = new DSChiefFab();
        chief = fab.newChief(gov, electionSize);
        iou = chief.IOU();

        delegate = new Voter(chief, gov, iou);
        delegator1 = new Voter(chief, gov, iou);
        delegator2 = new Voter(chief, gov, iou);
        gov.mint(address(delegate), 100 ether);
        gov.mint(address(delegator1), 10_000 ether);
        gov.mint(address(delegator2), 20_000 ether);

        proxy = new VoteDelegate(address(chief), address(delegate));

        delegate.setProxy(proxy);
        delegator1.setProxy(proxy);
        delegator2.setProxy(proxy);
    }

   function test_proxy_lock_free() public {
        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));

        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 0);

        delegate.doProxyLock(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 0);
        assertEq(gov.balanceOf(address(chief)), 100 ether);
        assertEq(iou.balanceOf(address(delegate)), 100 ether);
        assertEq(proxy.delegators(address(delegate)), 100 ether);

        delegate.doProxyFree(100 ether);
        assertEq(gov.balanceOf(address(delegate)), 100 ether);
        assertEq(gov.balanceOf(address(chief)), 0 ether);
        assertEq(iou.balanceOf(address(delegate)), 0);
        assertEq(proxy.delegators(address(delegate)), 0);
   }

   function test_delegator_lock_free() public {
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegator1.doProxyLock(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 0);
        assertEq(gov.balanceOf(address(chief)), 10_000 ether);
        assertEq(iou.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(proxy.delegators(address(delegator1)), 10_000 ether);

        delegator1.doProxyFree(10_000 ether);
        assertEq(gov.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(gov.balanceOf(address(chief)), 0 ether);
        assertEq(iou.balanceOf(address(delegator1)), 0);
        assertEq(proxy.delegators(address(delegator1)), 0);
   }

   function test_delegate_voting() public {
        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegate.doProxyLock(100 ether);
        delegator1.doProxyLock(10_000 ether);

        assertEq(gov.balanceOf(address(chief)), 10_100 ether);

        address[] memory yays = new address[](1);
        yays[0] = c1;
        cold.doProxyVote(yays);
        assertEq(chief.approvals(c1), 10_100 ether);
        assertEq(chief.approvals(c2), 0 ether);

        address[] memory _yays = new address[](1);
        _yays[0] = c2;
        hot.doProxyVote(_yays);
        assertEq(chief.approvals(c1), 0 ether);
        assertEq(chief.approvals(c2), 10_100 ether);
   }

   function testFail_delegate_attempts_steal() public {
        delegate.approveGov(address(proxy));
        delegate.approveIou(address(proxy));
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));

        delegate.doProxyLock(100 ether);
        delegator1.doProxyLock(10_000 ether);

        // Attempting to steal more MKR than you put in
        delegate.doProxyFree(101 ether);
   }

   function test_attempt_steal_with_ious() public {
        delegator1.approveGov(address(proxy));
        delegator1.approveIou(address(proxy));
        delegator2.approveGov(address(chief));
        delegator2.approveIou(address(proxy));

        delegator1.doProxyLock(10_000 ether);

        // You have enough IOU tokens, but you are still not marked as a delegate
        delegator2.doChiefLock(20_000 ether);
        assertEq(gov.balanceOf(address(proxy)), 10_000 ether);
        assertEq(iou.balanceOf(address(delegator1)), 10_000 ether);
        assertEq(gov.balanceOf(address(delegator2)), 20_000 ether);
        assertEq(iou.balanceOf(address(delegator2)), 20_000 ether);

        delegator2.doProxyFree(10_000 ether);
   }
}
