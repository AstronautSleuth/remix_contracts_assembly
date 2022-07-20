// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { OwnerAssembly } from "src/2_Owner_Assembly.sol";
import "forge-std/Test.sol";

abstract contract HelperContract {
    address constant DEPLOYER = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    address constant FAKE_OWNER = 0x1234123412341234123412341234123412341234;
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
}

contract OwnerAssemblyTest is Test, HelperContract {
    OwnerAssembly o;

    function setUp() public {
        o = new OwnerAssembly();
    }

    function testGetOwner() public {
        assertEq(o.getOwner(), DEPLOYER);
    }

    function testChangeOwner() public {
        vm.prank(DEPLOYER);
        o.changeOwner(FAKE_OWNER);
        assertEq(o.getOwner(), FAKE_OWNER);
    }

    function testOwnerSetEventEmittedOnChangeOwner() public {
        vm.prank(DEPLOYER);
        vm.expectEmit(true, true, false, false);
        emit OwnerSet(DEPLOYER, FAKE_OWNER);
        o.changeOwner(FAKE_OWNER);
    }

    function testChangeOwnerNotAsOwner() public {
        vm.prank(FAKE_OWNER);
        vm.expectRevert(bytes("Caller is not owner"));
        o.changeOwner(FAKE_OWNER);
    }
}