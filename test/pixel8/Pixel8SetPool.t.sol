// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8 } from "src/Pixel8.sol";
import { console2 as c } from "forge-std/Test.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { LibErrors } from "src/LibErrors.sol";

contract Pixel8SetPool is Pixel8TestBase {
  function test_SetPoolInConstructor_Succeeds() public {
    address poolAddr = address(0x789);
    Pixel8.Config memory config = _getDefaultPixel8Config();
    config.pool = poolAddr;
    pixel8 = new Pixel8(config);
    assertEq(pixel8.pool(), poolAddr);
  }

  function test_SetPoolWhenOwnerAndNotSet_Succeeds() public {
    address poolAddr = address(0x789);
    vm.prank(owner1);
    pixel8.setPool(poolAddr);
    assertEq(pixel8.pool(), poolAddr);
  }

  function test_SetPoolWhenAlreadySet_Fails() public {
    address poolAddr = address(0x789);
    vm.prank(owner1);
    pixel8.setPool(poolAddr);
    
    vm.prank(owner1);
    vm.expectRevert(LibErrors.PoolAlreadySet.selector);
    pixel8.setPool(address(0x123));
  }

  function test_SetPoolWhenNotOwner_Fails() public {
    vm.prank(authoriser1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, authoriser1));
    pixel8.setPool(address(0x789));

    address random = address(0x8876);
    vm.prank(random);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, random));
    pixel8.setPool(address(0x789));
  }
}
