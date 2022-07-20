// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title Owner
 * @dev Set & change owner
 */
contract OwnerAssembly {

    address private owner;

    modifier isOwner() {
        // Note: You can either use decimals or its hexidecimal equivalent when using inline assembly

        // Walkthrough of assembly code
        // 1. Retrieve the value that is stored at position 0 in storage
        // 2. Get the msg.sender
        // 3. XOR equality comparison
        // 4. Create error message
        // 5. Function signature for Error i.e. keccak256(Error(string)).
        // 6. Get the free memory location since the scratch space (first 64 bytes) is insufficient
        // 7. Store function signature at the free mem location
        // 8. Store the data offset at free mem location + 4 (sig)
        // 9. Store the length of the error message at free mem location + 4 (sig) + 32 (data offset)
        // 10. Store the error message at free mem location + 4 (sig) + 32 (data offset) + 32 (error message)
        // 11. Return 100 bytes (4 + 32 + 32 + 32) starting from the free mem location
        // assembly {
        //     let n := sload(0)
        //     let c := caller()
        //     if xor(n,c) {
        //         let err := "Caller is not owner"
        //         let sig := 0x08c379a000000000000000000000000000000000000000000000000000000000
        //         let ptr := mload(64)
        //         mstore(ptr, sig)
        //         mstore(add(ptr, 4), 32)
        //         mstore(add(ptr, 36), 19)
        //         mstore(add(ptr, 68), err)
        //         revert(ptr, 100)
        //     }
        // }
        // // This following code is even more gas optimized!
        assembly {
            let n := sload(0)
            let c := caller()
            if xor(n,c) {
                // length concatenated with message
                let combined := 0x1343616c6c6572206973206e6f74206f776e6572000000000000000000000000
                let sig := 0x08c379a000000000000000000000000000000000000000000000000000000000
                mstore(128, sig)
                mstore(132, 32)
                mstore(195, combined)
                revert(128, 100)
            }
        }
        _;
    }

    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        // Walkthrough of Assembly code
        // 1. Assign msg.sender to the var sender
        // 2. Store sender in storage at location 0
        // 3. Emit an event with 3 topics.

        // log3(offset, size, topic 0, topic 1, topic 2)
        // Since we are not returning anything from memory, offset and size can be 0.
        // Topic 0 is the keccak hash of the event signature i.e. keccak256(OwnerSet(address,address))
        // Topic 1 is the previous owner
        // Topic 2 is the new owner
        assembly {
            let sender := caller()
            sstore(0, sender)
            log3(0, 0, 0x342827c97908e5e2f71151c08502a66d44b6f758e3ac2f1de95f02eb95f0a735, 0x0, sender)
        }
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public isOwner {
        assembly {
            log3(0, 0, 0x342827c97908e5e2f71151c08502a66d44b6f758e3ac2f1de95f02eb95f0a735, sload(0), newOwner)
            sstore(0, newOwner)
        }
    }

    /**
     * @dev Return owner address
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        assembly {
            mstore(0, sload(0))
            return(0, 32)
        }
    }
}