// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title Ballot
 * @dev Implements voting process along with vote delegation
 */
contract BallotAssembly {

    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted;  // if true, that person already voted
        address delegate; // person delegated to
        uint vote;   // index of the voted proposal
    }

    struct Proposal {
        // If you can limit the length to a certain number of bytes, 
        // always use one of bytes1 to bytes32 because they are much cheaper
        bytes32 name;   // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    address public chairperson;

    mapping(address => Voter) internal _voters; // Renamed from voters to _voters so that we can implement an optimized getter function

    Proposal[] internal _proposals; // Renamed from proposals to _proposals so that we can implement an optimized getter function

    /**
     * @dev Create a new ballot to choose one of 'proposalNames'.
     * @param proposalNames names of proposals
     */
    constructor(bytes32[] memory proposalNames) {
        assembly {
            // 1. Assign msg.sender to the state variable chairperson
            let sender := caller()                              // get msg.sender
            sstore(0, sender)                                   // store msg.sender at storage location 0
            

            // 2. Set the weight of chairperson to 1
            mstore(0, sender)                                   // store msg.sender at memory location 0
            mstore(32, _voters.slot)                            // store storage location of _voters mapping at memory location 32
            let slot := keccak256(0, 64)                        // keccak the first 64 bytes to get the storage location of the voter struct corresponding to msg.sender
            sstore(slot, 1)                                     // update the weight of the chairperson


            // 3. Push an array of proposalNames to the state variable proposals
            mstore(0, _proposals.slot)                          // store _proposals array at memory location 0
            slot := keccak256(0, 32)                            // keccak the first 32 bytes to get the storage location of the first element in the _proposals array

            let len := mload(proposalNames)                     // length is the first element at the memory location of the proposalNames argument
            sstore(_proposals.slot, len)                        // store the length at the storage location of the _proposals array

            let nameLocInMemory := add(proposalNames, 32)       // get the first proposal in proposalNames

            // For loop
            for
            { let end := add(nameLocInMemory, mul(len, 32)) }   // calculate memory location of last proposal
            lt(nameLocInMemory, end)                            // while current memory location is less than last memory location
            { nameLocInMemory := add(nameLocInMemory, 32) }     // add an offset of 32 to get the next proposal
            {
                sstore(slot, mload(nameLocInMemory))            // store proposal 
                sstore(add(slot, 1), 0)                         // voteCount is stored at an offset of 1
                slot := add(slot , 2)                           // calculate the next storage location to store the next proposal
            }
        }
    }

    /**
     * @dev Give 'voter' the right to vote on this ballot. May only be called by 'chairperson'.
     * @param voter address of voter
     */
    function giveRightToVote(address voter) public {
        assembly {
            // Helper function for reverting
            function _revert(message, length) {
                let sig := 0x08c379a000000000000000000000000000000000000000000000000000000000
                mstore(0, sig)
                mstore(4, 32)
                mstore(36, length)
                mstore(68, message)
                revert(0, 100) 
            }

            // Revert if msg.sender != chairperson
            if xor(caller(), sload(0)) {
                // Error messages split into 2 because each var can only hold 32 bytes
                let err := "Only chairperson can give right "
                let err2 := "to vote."
                mstore(0, 0x08c379a000000000000000000000000000000000000000000000000000000000)
                mstore(4, 32)
                mstore(36, 40)
                mstore(68, err)
                mstore(100, err2)
                revert(0, 132)
            }

            // Calculate the storage location of value based on this key (voter)
            mstore(0, voter)
            mstore(32, _voters.slot)
            let slot := keccak256(0, 64)

            // Offset of 1 since voted and delegate can be packed into a single 32 bytes
            let packed := sload(add(slot, 1))

            // Bitwise AND operation to retrieve the right most byte
            // Revert if voter.voted != 0
            if and(and(packed, 0xff), 1) {
                _revert("The voter already voted.", 24)
            }

            // Revert if voter.weight != 0
            if xor(sload(slot), 0) {
                _revert("", 0)

            }

            // Assign voter weight to 1
            sstore(slot, 1)
        }
    }

    /**
     * @dev Delegate your vote to the voter 'to'.
     * @param to address to which vote is delegated
     */
    function delegate(address to) public {
        assembly {
            // Helper function for reverting
            function _revert(message, length) {
                let sig := 0x08c379a000000000000000000000000000000000000000000000000000000000
                mstore(0, sig)
                mstore(4, 32)
                mstore(36, length)
                mstore(68, message)
                revert(0, 100) 
            }

            // Helper function for calculating slot in mapping
            function _getMappingSlot(key) -> slot {
                mstore(0, key)
                mstore(32, _voters.slot) // Since we only have 1 mapping, we can "hardcode" the position
                slot := keccak256(0, 64)
            }

            let sender := caller()
            let senderSlot := _getMappingSlot(sender)

            // Offset of 1 since voted and delegate can be packed into a single 32 bytes
            let packed := sload(add(senderSlot, 1))

            // Revert if sender.voted != 0
            // Bitwise AND operation to retrieve the right most byte
            if eq(and(packed, 0xff), 1) {
                _revert("You already voted.", 18)
            }

            // Revert if to == self
            if eq(to, sender) {
                _revert("Self-delegation is disallowed.", 30)
            }

            // Calculate the storage location of value based on this key (to)
            let toSlot := _getMappingSlot(to)

            // Offset of 1 since voted and delegate can be packed into a single 32 bytes
            packed := sload(add(toSlot, 1))

            // Shift right by 1 byte (bool takes 8 bits) to get delegate
            let _delegate := shr(8, packed)

            // Placeholder var for next step
            let temp

            // Check that there is no loop
            for { } xor(_delegate, 0) { } {

                // Revert if delgate == msg.sender
                if eq(_delegate, sender) {
                    _revert("Found loop in delegation.", 25)
                }

                // Get the delegate's delegate
                temp := _getMappingSlot(_delegate)
                temp := sload(add(temp, 1))
                _delegate := shr(8, temp)
            }

            // set sender.voted = true and sender.delegate = to
            // Bitwise OR operation to set bits.
            // Final packed value should be 0x00000000000<delegate's address><voted>
            let updatedPacked := or(0, to) // set delegate's address = to address
            updatedPacked := shl(8, updatedPacked) // shift address left by 1 byte
            updatedPacked := or(updatedPacked, 1) // set voted = true

            // Store newly packed value back into the correct slot (and offset)
            sstore(add(senderSlot, 1), updatedPacked)

            // Get To's voted
            switch and(packed, 0xff) 
            case 0 {
                // If to has not voted, add sender's weight to to's weight
                sstore(toSlot, add(sload(toSlot), sload(senderSlot)))
            }
            case 1 {
                // If to has voted, add sender's weight to to's vote's voteCount
                // Calculate the location of Proposals in storage
                mstore(0, _proposals.slot)
                let proposalsSlot := keccak256(0, 32)

                // Calculate the offset required to retrieve the correct slot corresponding to to's vote.
                let index := sload(add(toSlot, 2)) // get to's vote
                let offset := mul(2, index) // get offset in Proposals
                let totalOffset := add(offset, 1) // add offset of 1 to get voteCount
                let voteCountSlot := add(proposalsSlot, totalOffset) // add total offset to get to's vote's voteCount slot

                // Increment to's vote's voteCount by sender's weight
                sstore(voteCountSlot, add(sload(voteCountSlot), sload(senderSlot)))
            }

        }
    }

    /**
     * @dev Give your vote (including votes delegated to you) to proposal 'proposals[proposal].name'.
     * @param proposal index of proposal in the proposals array
     */
    function vote(uint proposal) public {
        assembly {
            // Helper function for reverting
            function _revert(message, length) {
                let sig := 0x08c379a000000000000000000000000000000000000000000000000000000000
                mstore(0, sig)
                mstore(4, 32)
                mstore(36, length)
                mstore(68, message)
                revert(0, 100) 
            }

            mstore(0, caller())
            mstore(32, _voters.slot)
            let senderSlot := keccak256(0, 64)
            let weight := sload(senderSlot)
            
            // Revert if sender's weight is 0
            if eq(weight, 0) {
                _revert("Has no right to vote", 20)
            }

            // Offset of 1 since voted and delegate can be packed into a single 32 bytes
            let packed := sload(add(senderSlot, 1))

            // Revert if sender.voted == true
            if eq(and(packed, 0xff), 1) {
                _revert("Already voted.", 14)
            }

            // Bitwise OR operation to set sender.voted = true and update storage
            packed := or(packed, 1)
            sstore(add(senderSlot, 1), packed)

            // Set sender.vote = proposal in storage
            sstore(add(senderSlot, 2), proposal)

            // Increment proposal.voteCount by sender.weight
            mstore(0, _proposals.slot)
            let proposalsSlot := keccak256(0, 32)
            let offset := mul(proposal, 2)
            let totalOffset := add(offset, 1)
            let voteCountSlot := add(proposalsSlot, totalOffset)
            sstore(voteCountSlot, add(sload(voteCountSlot), weight))
        }
    }

    /**
     * @dev Computes the winning proposal taking all previous votes into account.
     * @return winningProposal_ index of winning proposal in the proposals array
     */
    function winningProposal() public view
            returns (uint winningProposal_)
    {
        assembly {
            mstore(0, _proposals.slot)
            let voteCountSlot := add(keccak256(0, 32), 1)

            // Assume first proposal is the winner
            let winningVoteCount := sload(voteCountSlot)
            let vc := 0
            let len := sload(_proposals.slot)

            // Loop through the rest of proposals to find the winning proposal
            for { let i := 1 } lt(i, len) { i := add(i, 1) } {
                voteCountSlot := add(voteCountSlot, 2)
                vc := sload(voteCountSlot)
                if gt(vc, winningVoteCount) {
                    winningProposal_ := i
                    winningVoteCount := vc
                }
            }
        }
    }

    /**
     * @dev Calls winningProposal() function to get the index of the winner contained in the proposals array and then
     * @return winnerName_ the name of the winner
     */
    function winnerName() public view
            returns (bytes32 winnerName_)
    {   
        assembly {
            mstore(0, _proposals.slot)
            let voteCountSlot := add(keccak256(0, 32), 1)

            // Assume first proposal is the winner
            let winningVoteCount := sload(voteCountSlot)
            let vc := 0
            let len := sload(_proposals.slot)

            // Loop through the rest of proposals to find the winning proposal's name
            for { let i := 1 } lt(i, len) { i := add(i, 1) } {
                voteCountSlot := add(voteCountSlot, 2)
                vc := sload(voteCountSlot)
                if gt(vc, winningVoteCount) {
                    winnerName_ := sload(sub(voteCountSlot, 1))
                    winningVoteCount := vc
                }
            }
        }
    }

    function voters(address _a) public view returns(uint, bool, address, uint) {
        assembly {
            mstore(0, _a)
            mstore(32, _voters.slot)
            let slot := keccak256(0, 64)
            let packed := sload(add(slot, 1))
            mstore(0, sload(slot))
            mstore(32, and(packed, 0xff))
            mstore(64, shr(8, packed))
            mstore(96, sload(add(slot, 2)))
            return(0, 128)
        }
    }

    function proposals(uint256 i) public view returns(bytes32, uint256) {
        assembly {
            mstore(0, _proposals.slot)
            let slot := keccak256(0, 32)
            let offset := mul(i, 2)
            slot := add(slot, offset)
            mstore(0, sload(slot))
            mstore(32, sload(add(slot, 1)))
            return(0, 64)
        }
    }

    // Get storage location of mapping
    // Note: It is currently not possible to call sol functions from inline asm
    // https://stackoverflow.com/questions/69514295/solidity-inline-assembly-calling-other-functions-within-one-contract-and-using
    function mapLocation(address key, uint256 slot) public pure returns (uint256) {
        // This is equivalent to
        // 1. Solidity: uint256(keccak256(abi.encode(key, slot)));
        // 2. Web3.js: web3.utils.soliditySha3(web3.eth.abi.encodeParameters(["address", "uint256"], [key, slot]))
        assembly {
            mstore(0, key)
            mstore(32, slot)
            mstore(0, keccak256(0, 64))
            return(0, 32)
        }
    }
}
