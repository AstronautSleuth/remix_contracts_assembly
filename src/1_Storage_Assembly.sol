// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
contract StorageAssembly {

    uint256 public number;

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function store(uint256 num) public {
        assembly {
            sstore(0x00, num)       // Store num into storage position 0x00
        }
    }

    /**
     * @dev Return value
     * @return value of 'number'
     */
    function retrieve() public view returns( uint256) {
        assembly {
            let n := sload(0x00)    // Retrieve the value that is stored at position 0x00 in storage and store it on the stack.
            mstore(0x00, n)         // Move this value from the stack to memory
            return(0x00, 32)        // Return 32 bytes at offset 0 from memory
        }
    }
}