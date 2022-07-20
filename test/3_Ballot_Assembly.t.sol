// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { BallotAssembly } from "src/3_Ballot_Assembly.sol";
import "@std/Test.sol";
import "@std/console.sol";

abstract contract HelperContract {
    address constant DEPLOYER = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address constant VOTER_ONE = 0x0000000000000000000000000000000000000001;
    address constant VOTER_TWO = 0x0000000000000000000000000000000000000002;
    address constant VOTER_THREE = 0x0000000000000000000000000000000000000003;
    address constant VOTER_FOUR = 0x0000000000000000000000000000000000000004;
}

contract BallotAssemblyTest is Test, HelperContract {
    using stdStorage for StdStorage;
    bytes32[] proposalNames;
    BallotAssembly b;

    function setUp() public {
        proposalNames.push(keccak256("Alice"));
        proposalNames.push(keccak256("Bob"));
        proposalNames.push(keccak256("Charlie"));
        b = new BallotAssembly(proposalNames);
    }

    function testCannotGiveRightToVoteAsNonChairman() public {
        vm.prank(VOTER_ONE);
        vm.expectRevert(bytes("Only chairperson can give right to vote."));
        b.giveRightToVote(VOTER_ONE);
    }

    function testCannotGiveRightToVoteIfAlreadyVoted() public {
        b.giveRightToVote(VOTER_ONE);
        vm.prank(VOTER_ONE);
        b.vote(0);
        vm.expectRevert(bytes("The voter already voted."));
        b.giveRightToVote(VOTER_ONE);
    }

    function testCannotGiveRightToVoteTwice() public {
        b.giveRightToVote(VOTER_ONE);
        vm.expectRevert();
        b.giveRightToVote(VOTER_ONE);
    }

    function testGiveRightToVote() public {
        b.giveRightToVote(VOTER_ONE);
        (uint weight,,,) = b.voters(VOTER_ONE);
        assertEq(weight, 1);
    }

    function testCannotDelegateIfAlreadyVoted() public {
        b.giveRightToVote(VOTER_ONE);
        vm.startPrank(VOTER_ONE);
        b.vote(0);
        vm.expectRevert("You already voted.");
        b.delegate(VOTER_TWO);
    }

    function testCannotDelegateToSelf() public {
        b.giveRightToVote(VOTER_ONE);
        vm.prank(VOTER_ONE);
        vm.expectRevert("Self-delegation is disallowed.");
        b.delegate(VOTER_ONE);
    }

    function testCannotDelegateLoop() public {
        b.giveRightToVote(VOTER_ONE);
        vm.prank(VOTER_ONE);
        b.delegate(VOTER_TWO);
        vm.prank(VOTER_TWO);
        b.delegate(VOTER_THREE);
        vm.prank(VOTER_THREE);
        vm.expectRevert("Found loop in delegation.");
        b.delegate(VOTER_ONE);
    }

    function testDelegateVoted() public {
        b.giveRightToVote(VOTER_ONE);
        b.giveRightToVote(VOTER_TWO);
        vm.prank(VOTER_TWO);
        b.vote(0);
        vm.prank(VOTER_ONE);
        b.delegate(VOTER_TWO);
        (, uint voteCount) = b.proposals(0);
        assertEq(voteCount, 2);
    }

    function testDelegateNotVoted() public {
        b.giveRightToVote(VOTER_ONE);
        b.giveRightToVote(VOTER_TWO);
        vm.prank(VOTER_ONE);
        b.delegate(VOTER_TWO);
        (uint weight,,,) = b.voters(VOTER_TWO);
        assertEq(weight, 2);
    }

    function testCannotVoteIfNoRight() public {
        vm.prank(VOTER_ONE);
        vm.expectRevert("Has no right to vote");
        b.vote(0);
    }

    function testCannotVoteIfAlreadyVoted() public {
        b.giveRightToVote(VOTER_ONE);
        vm.startPrank(VOTER_ONE);
        b.vote(0);
        vm.expectRevert("Already voted.");
        b.vote(0);
    }

    function testVote() public {
        b.giveRightToVote(VOTER_ONE);
        vm.prank(VOTER_ONE);
        b.vote(0);
        (, uint voteCount) = b.proposals(0);
        assertEq(voteCount, 1);
    }
    function testWinningProposal() public {
        b.giveRightToVote(VOTER_ONE);
        b.giveRightToVote(VOTER_TWO);
        b.giveRightToVote(VOTER_THREE);
        b.vote(1);
        vm.prank(VOTER_ONE);
        b.vote(2);
        vm.prank(VOTER_TWO);
        b.vote(0);
        vm.prank(VOTER_THREE);
        b.vote(2);
        uint winningProposal = b.winningProposal();
        assertEq(winningProposal, 2);
    }

    function testWinnerName() public {
        b.giveRightToVote(VOTER_ONE);
        b.giveRightToVote(VOTER_TWO);
        b.giveRightToVote(VOTER_THREE);
        b.vote(1);
        vm.prank(VOTER_ONE);
        b.vote(2);
        vm.prank(VOTER_TWO);
        b.vote(0);
        vm.prank(VOTER_THREE);
        b.vote(2);
        bytes32 winnerName = b.winnerName();
        assertEq(winnerName, keccak256("Charlie"));
    }
}