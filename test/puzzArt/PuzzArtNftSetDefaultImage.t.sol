// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Vm } from "forge-std/Vm.sol";
import { console2 as c } from "forge-std/Test.sol";
import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";

contract PuzzArtNftSetDefaultImage is PuzzArtNftTestBase {
  function setUp() virtual override public {
    super.setUp();

    vm.startPrank(owner1);
    puzzArt.setLotteryNFT(lotteryNft_addr);
    vm.stopPrank();
  }

  function test_SetDefaultImageWhenOwner_Succeeds() public {
    vm.prank(owner1);
    puzzArt.setDefaultImage("newImage");
    assertEq(puzzArt.defaultImage(), "newImage");
  }

  function test_SetDefaultImageWhenOwner_EmitsEvent() public {
    vm.prank(wallet1);
    _puzzArt_mint(wallet1, 1, "uri", 1);

    vm.recordLogs();

    vm.prank(puzzArt.owner());
    puzzArt.setDefaultImage("ten");

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 1, "Invalid entry count");
    assertEq(entries[0].topics.length, 1, "Invalid event count");
    assertEq(
        entries[0].topics[0],
        keccak256("BatchMetadataUpdate(uint256,uint256)"),
        "Invalid event signature"
    );
    (uint256 from, uint256 to) = abi.decode(entries[0].data, (uint256, uint256));
    assertEq(from, 1);
    assertEq(to, 1);
  }

  function test_SetDefaultImageWhenNotOwner_Fails() public {
    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, minter1));
    puzzArt.setDefaultImage("newImage");

    address random = address(0x8876);
    vm.prank(random);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
    puzzArt.setDefaultImage("newImage");
  }
}
