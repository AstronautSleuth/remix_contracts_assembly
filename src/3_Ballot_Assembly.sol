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
            mstore(0, _proposals.slot)                          // store storage location of _proposals array at memory location 0
            slot := keccak256(0, 32)                            // keccak the first 32 bytes to get the storage location of the first element in the _proposals array

            let len := mload(proposalNames)                     // length is the first element at the memory location of the proposalNames argument
            sstore(_proposals.slot, len)                        // store the length of proposalNames at the storage location of the _proposals array

            let nameLocInMemory := add(proposalNames, 32)       // get the first proposal in proposalNames, offset of 32 is added since the first 32 bytes is used by length

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
                mstore(0, sig)                                  // store "Error" signature at memory location 0
                mstore(4, 32)                                   // store offset at memory location 4
                mstore(36, length)                              // store length at memory location 36 (4 + 32)
                mstore(68, message)                             // store message at memory location 68 (4 + 32 + 32)
                revert(0, 100)                                  // revert with offset 0 and length of 100 (4 + 32 + 32 + 32)
            }


            // 1. Revert if msg.sender != chairperson
            if xor(caller(), sload(0)) {                        // bitwise XOR operation is used to check if msg.sender != chairperson
                let sig := 0x08c379a000000000000000000000000000000000000000000000000000000000
                let err := "Only chairperson can give right "   // first 32 bytes of the error message
                let err2 := "to vote."                          // remaining 8 bytes of the error message
                mstore(0, sig)                                  // store "Error" signature at memory location 0
                mstore(4, 32)                                   // store offset at memory location 4
                mstore(36, 40)                                  // store length at memory location 36 (4 + 32)
                mstore(68, err)                                 // store first part of message at memory location 68 (4 + 32 + 32)
                mstore(100, err2)                               // store second part of message at memory location 100 (4 + 32 + 32 + 32)
                revert(0, 132)                                  // revert with offset 0 and length of 132 (4 + 32 + 32 + 32 + 32)
            }


            // 2. Revert if voter already voted
            mstore(0, voter)                                    // store voter at memory location 0
            mstore(32, _voters.slot)                            // store storage location of _voters mapping at memory location 32
            let slot := keccak256(0, 64)                        // keccak the first 64 bytes to get the storage location of the voter struct corresponding to voter

            let packed := sload(add(slot, 1))                   // add an offset of 1 since voted and delegate are packed into a single 32 bytes
            
            if and(and(packed, 0xff), 1) {                      // bitwise AND operation to retrieve the right most byte and to check if voter has voted
                _revert("The voter already voted.", 24)         // revert with the correct error message and length
            }


            // 3. Revert if voter’s weight is not 0
            if xor(sload(slot), 0) {                            // bitwise XOR operation is used to check if voter's weight != 0
                _revert("", 0)                                  // revert with the correct error message and length

            }


            // 4. Increase the voter’s weight to 1
            sstore(slot, 1)                                     // update the weight of the voter
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
                mstore(0, sig)                                          // store "Error" signature at memory location 0
                mstore(4, 32)                                           // store offset at memory location 4
                mstore(36, length)                                      // store length at memory location 36 (4 + 32)
                mstore(68, message)                                     // store message at memory location 68 (4 + 32 + 32)
                revert(0, 100)                                          // revert with offset 0 and length of 100 (4 + 32 + 32 + 32)
            }

            // Helper function for calculating slot in mapping
            function _getMappingSlot(key) -> slot {
                mstore(0, key)                                          // store key at memory location 0
                mstore(32, _voters.slot)                                // store storage location of _voters mapping at memory location 32
                slot := keccak256(0, 64)                                // keccak the first 64 bytes to get the storage location of the voter struct corresponding to key
            }

            // 1. Revert if voter already voted
            let sender := caller()                                      // get msg.sender
            let senderSlot := _getMappingSlot(sender)                   // get the storage location of the voter struct corresponding to msg.sender

            let packed := sload(add(senderSlot, 1))                     // add an offset of 1 since voted and delegate are packed into a single 32 bytes

            if and(and(packed, 0xff), 1) {                              // bitwise AND operation to retrieve the right most byte and to check if voter has voted
                _revert("You already voted.", 18)                       // revert with the correct error message and length
            }


            // 2. Revert if trying to delegate to self
            if eq(to, sender) {                                         // eq operation to check if msg.sender is trying to delegate to self
                _revert("Self-delegation is disallowed.", 30)           // revert with the correct error message and length
            }


            // 3. Revert if a delegate loop exists
            let toSlot := _getMappingSlot(to)                           // get the storage location of the voter struct corresponding to to
            packed := sload(add(toSlot, 1))                             // add an offset of 1 since voted and delegate are packed into a single 32 bytes

            let _delegate := shr(8, packed)                             // shift right by 1 byte (bool takes 8 bits) to get delegate

            let temp                                                    // temporary placeholder variable

            for { } xor(_delegate, 0) { } {                             // bitwise XOR operation is used to check if delegate 
                if eq(_delegate, sender) {                              // eq operation to check if delegate is msg.sender
                    _revert("Found loop in delegation.", 25)            // revert with the correct error message and length
                }
                temp := _getMappingSlot(_delegate)                      // get the storage location of the voter struct corresponding to _delegate
                temp := sload(add(temp, 1))                             // add an offset of 1 since voted and delegate are packed into a single 32 bytes 
                _delegate := shr(8, temp)                               // get the delegate's delegate
            }


            let updatedPacked := or(0, to)                              // bitwise OR operation to update a new packed variable with to address
            updatedPacked := shl(8, updatedPacked)                      // shift left by 1 byte 
            updatedPacked := or(updatedPacked, 1)                       // bitwise OR operation to set voted = true to the updated packed variable

            sstore(add(senderSlot, 1), updatedPacked)                   // store the updated packed variable (delegate + voted) for sender


            // 4. If delegate already voted, increase the voteCount of the delegate’s vote by sender’s weight
            // 5. If delegate has not voted, increase delegate’s weight by sender’s weight
            switch and(packed, 0xff)                                    // bitwise AND operation to retrieve the right most byte
            case 0 {                                                    // if right most byte is 0 i.e. delegate has not voted
                sstore(
                    toSlot,
                    add(sload(toSlot), sload(senderSlot))
                )                                                       // increment delegate's weight with sender's weight
            }
            case 1 {                                                    // if right most byte is 1 i.e. delegate has voted          
                mstore(0, _proposals.slot)                              // store storage location of _proposals array at memory location 0
                let proposalsSlot := keccak256(0, 32)                   // keccak the first 32 bytes to get the storage location of the first element in the _proposals array

                let index := sload(add(toSlot, 2))                      // add an offset of 2 to get to's vote
                let offset := mul(2, index)                             // multiply by 2 (name, voteCount) to get the index in Proposals
                let totalOffset := add(offset, 1)                       // add another offset of 1 to get to's vote's voteCount
                let voteCountSlot := add(proposalsSlot, totalOffset)    // get the storage location of to's vote's voteCount slot

                sstore(
                    voteCountSlot,
                    add(sload(voteCountSlot), sload(senderSlot))
                )                                                       // increment to's vote's voteCount by sender's weight 
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
