// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";

contract Pixel8SetAuthoriser is Pixel8TestBase {
  function test_SetAuthoriserWhenOwner_Succeeds() public {
    vm.prank(owner1);
    pixel8.setAuthoriser(address(0x789));
    assertEq(pixel8.authoriser(), address(0x789));
  }

  function test_SetAuthoriserWhenNotOwner_Fails() public {
    vm.prank(authoriser1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, authoriser1));
    pixel8.setAuthoriser(address(0x789));
  }
}
