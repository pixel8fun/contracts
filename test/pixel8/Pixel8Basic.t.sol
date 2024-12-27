// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { LibErrors } from "src/LibErrors.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";

contract Pixel8Basic is Pixel8TestBase {
  function test_DefaultConfig() public {
    assertEq(pixel8.VERSION(), 1, "version");
    assertEq(pixel8.name(), "Pixel8", "name");
    assertEq(pixel8.symbol(), "PIXEL8", "symbol");
    assertEq(pixel8.owner(), owner1, "owner");
    assertEq(pixel8.authoriser(), authoriser1, "authoriser");
    assertEq(pixel8.pool(), address(0), "pool");
    assertEq(pixel8.defaultImage(), "img", "defaultImg");
    assertEq(pixel8.forceSwapCost(), 0.01 ether, "forceSwapCost");
    assertEq(pixel8.gameOver(), false, "gameOver");
    assertEq(pixel8.gameOverRevealThreshold(), 10, "gameOverRevealThreshold");
    assertEq(pixel8.totalSupply(), 0, "totalSupply");

    Pixel8.Royalties memory devRoyalties = pixel8.getDevRoyalties();
    assertEq(devRoyalties.amount, 0, "devRoyalties.amount should start at 0");

    Pixel8.Royalties memory creatorRoyalties = pixel8.getCreatorRoyalties();
    assertEq(creatorRoyalties.amount, 0, "creatorRoyalties.amount should start at 0");
  }

  function test_SetPoolOnlyOnce() public {
    vm.startPrank(owner1);
    pixel8.setPool(address(1));
    vm.expectRevert(LibErrors.PoolAlreadySet.selector);
    pixel8.setPool(address(2));
    vm.stopPrank();
  }

  function test_SetPoolNotZeroAddress() public {
    vm.startPrank(owner1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidAddress.selector, address(0)));
    pixel8.setPool(address(0));
    vm.stopPrank();
  }
}
