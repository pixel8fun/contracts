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

    Pixel8.DevRoyalties memory devRoyalties = pixel8.getDevRoyalties();
    assertEq(devRoyalties.feeBips, 1000, "devRoyalties.feeBips");
    assertEq(devRoyalties.receiver, owner1, "devRoyalties.receiver");

    Pixel8.PrizePool memory prizePool = pixel8.getPrizePool();
    assertEq(prizePool.feeBips, 1000, "prizePool.feeBips");
    assertEq(prizePool.pot, 0, "prizePool.pot");

    assertEq(pixel8.getPrizePoolPot(), 0, "getPrizePoolPot");
    
    assertEq(pixel8.gameOver(), false, "gameOver");
    assertEq(pixel8.gameOverRevealThreshold(), 10, "gameOverRevealThreshold");

    assertEq(pixel8.totalSupply(), 0, "totalSupply");
    (address r1, uint r2) = pixel8.royaltyInfo(0, 100);
    assertEq(r1, pixel8_addr, "royaltyInfo.receiver");
    assertEq(r2, 20, "royaltyInfo.fee");

    (address rec, uint fee) = pixel8.getRoyaltyInfo();
    assertEq(rec, pixel8_addr, "getRoyaltyInfo.receiver");
    assertEq(fee, 2000, "getRoyaltyInfo.fee");
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
