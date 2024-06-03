// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { PuzzArtNftTestBase } from "./PuzzArtNftTestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";


contract PuzzArtNftSetMinter is PuzzArtNftTestBase {
  function test_SetMinterWhenOwner_Succeeds() public {
    vm.prank(owner1);
    puzzArt.setMinter(address(0x789));
    assertEq(puzzArt.minter(), address(0x789));
  }

  function test_SetMinterWhenNotOwner_Fails() public {
    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, minter1));
    puzzArt.setMinter(address(0x789));

    address random = address(0x8876);
    vm.prank(random);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
    puzzArt.setMinter(address(0x789));
  }
}
