// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { Owner } from "src/2_Owner.sol";
import "forge-std/Test.sol";

abstract contract HelperContract {
    address constant DEPLOYER = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address constant FAKE_OWNER = 0x1234123412341234123412341234123412341234;
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
}

// Tests are just for generating gas report, the actual
// tests are for the assembly contract.
contract OwnerTest is Test, HelperContract {
    Owner o;

    function setUp() public {
        o = new Owner();
    }

    function testGetOwner() public {
        o.getOwner();
    }

    function testChangeOwner() public {
        vm.prank(DEPLOYER);
        o.changeOwner(FAKE_OWNER);
        o.getOwner();
    }

    function testOwnerSetEventEmittedOnChangeOwner() public {
        vm.prank(DEPLOYER);
        o.changeOwner(FAKE_OWNER);
    }

    function testChangeOwnerNotAsOwner() public {
        vm.prank(FAKE_OWNER);
        vm.expectRevert(bytes("Caller is not owner"));
        o.changeOwner(FAKE_OWNER);
    }
}