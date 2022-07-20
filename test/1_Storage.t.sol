// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Storage } from "src/1_Storage.sol";
import "@std/Test.sol";

// Tests are just for generating gas report, the actual
// tests are for the assembly contract.
contract StorageTest is Test {
    Storage s;
    uint256 constant NUM = 1337;

    function setUp() public {
        s = new Storage();
    }

    function testStore() public {
        s.store(NUM);
    }

    function testRetrieve() public {
        s.store(NUM);
        s.retrieve();
    }

}