// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { StorageAssembly } from "src/1_Storage_Assembly.sol";
import "forge-std/Test.sol";

contract StorageAssemblyTest is Test {
    using stdStorage for StdStorage;
    StorageAssembly s;
    uint256 constant NUM = 1337;

    function setUp() public {
        console.log("Testing StorageAssembly");
        s = new StorageAssembly();
    }

    function testStore() public {
        s.store(NUM);
        uint256 slot = stdstore.target(address(s)).sig(s.number.selector).find();
        assertEq(slot, 0);
    }

    function testRetrieve() public {
        s.store(NUM);
        uint256 _num = s.retrieve();
        assertEq(_num, NUM);
    }
}