// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { console2 as c } from "forge-std/Test.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";

contract Pixel8SetDefaultImage is Pixel8TestBase {
  function setUp() virtual override public {
    super.setUp();
  }

  function test_SetDefaultImageWhenOwner_Succeeds() public {
    vm.prank(owner1);
    pixel8.setPool(pool1);

    vm.prank(pool1);
    pixel8.batchMint(wallet1, 1, 1);

    vm.recordLogs();

    vm.prank(owner1);
    pixel8.setDefaultImage("img2");

    assertEq(pixel8.defaultImage(), "img2");
    assertEq(pixel8.tokenURI(1), _buildDefaultTokenUri(1));

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 1, "Invalid event count");
    assertEq(
        keccak256(entries[0].data),
        keccak256(abi.encode(uint256(1), pixel8.totalSupply())),
        "Invalid event data"
    );
  }

  function test_SetDefaultImageWhenNotOwner_Fails() public {
    vm.prank(authoriser1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, authoriser1));
    pixel8.setDefaultImage("img2");

    address random = address(0x8876);
    vm.prank(random);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
    pixel8.setDefaultImage("img2");
  }
}
