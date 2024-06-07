// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { Pixel8NftTestBase } from "./Pixel8NftTestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";


contract Pixel8NftSetPool is Pixel8NftTestBase {
  function test_SetPoolWhenOwner_Succeeds() public {
    vm.prank(owner1);
    pixel8.setPool(address(0x789));
    assertEq(pixel8.pool(), address(0x789));
  }

  function test_SetPoolWhenNotOwner_Fails() public {
    vm.prank(minter1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, minter1));
    pixel8.setPool(address(0x789));

    address random = address(0x8876);
    vm.prank(random);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
    pixel8.setPool(address(0x789));
  }
}
