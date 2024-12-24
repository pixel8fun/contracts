// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { LibErrors } from "src/LibErrors.sol";


contract Pixel8PrizePool is Pixel8TestBase {
  function setUp() public override {
    super.setUp();

    vm.startPrank(owner1);
    pixel8.setPool(pool1);    
    vm.stopPrank();

    payable(pixel8_addr).transfer(0.0006 ether);    
  }

  function test_GetPrizePoolPot_PriorToGameOver_CalculatesBasedOnBalance() public {
    assertEq(pixel8.getPrizePoolPot(), 0.0003 ether, "getPrizePoolPot");
    payable(pixel8_addr).transfer(0.0006 ether);    
    assertEq(pixel8.getPrizePoolPot(), 0.0006 ether, "getPrizePoolPot");
  }

  function test_GameIsNotOverIfTileRevealThresholdNotYetReached() public {
    _mintAndRevealTiles(9);

    payable(pixel8_addr).transfer(0.0006 ether);    

    assertEq(pixel8.gameOver(), false, "gameOver");
    assertEq(pixel8.getPrizePoolPot(), 0.0006 ether, "prize pool pot still incrementing");
    assertEq(pixel8.calculatePrize(wallet1), 0, "no prize claimable yet");
  }

  function test_GameIsOverWhenTileRevealThresholdReached() public {
    _mintAndRevealTiles(10);

    payable(pixel8_addr).transfer(0.0006 ether);        

    assertEq(pixel8.gameOver(), true, "gameOver");
    assertEq(pixel8.getPrizePoolPot(), 0.0003 ether, "prize pot unchanged once game over");
    assertEq(pixel8.calculatePrize(wallet1), 0.0003 ether * 45 / 100, "prize claimable yet");
  }

  function test_WhenGameIsOver_HaveClaimablePrizes() public {
    _mintAndRevealTiles(10);

    assertEq(pixel8.highestPoints(0), wallet1);
    assertEq(pixel8.highestPoints(1), wallet2);
    assertEq(pixel8.highestPoints(2), wallet3);

    assertEq(pixel8.calculatePrize(wallet1), 0.0003 ether * 45 / 100, "1st points");
    assertEq(pixel8.calculatePrize(wallet2), 0.0003 ether * 25 / 100, "2nd points");
    assertEq(pixel8.calculatePrize(wallet3), 0.0003 ether * 15 / 100, "3rd points");
  }

  function test_WhenGameIsOver_CanClaimPrizeOnce() public {
    _mintAndRevealTiles(10);

    uint claimableExpected = 0.0003 ether * 45 / 100;

    assertEq(pixel8.calculatePrize(wallet1), claimableExpected);
    assertEq(pixel8.prizeClaimed(wallet1), false);

    uint balanceBefore = wallet1.balance;
    pixel8.claimPrize(wallet1);
    assertEq(wallet1.balance, balanceBefore + claimableExpected);

    assertEq(pixel8.prizeClaimed(wallet1), true);
    assertEq(pixel8.calculatePrize(wallet1), claimableExpected);

    vm.expectRevert(abi.encodeWithSelector(LibErrors.PrizeAlreadyClaimed.selector, wallet1));
    pixel8.claimPrize(wallet1);
  }

  // Helper methods

  function _mintAndRevealTiles(uint _maxToReveal) internal {
    // wallet3 - 2 points
    vm.prank(pool1);
    pixel8.batchMint(wallet3, 1, 2);
    for (uint i = 1; i <= 2 && i <= _maxToReveal; i++) {
      vm.prank(wallet3);
      _pixel8_reveal(wallet3, i, "uri1");
    }

    // wallet2 - 3 points
    vm.prank(pool1);
    pixel8.batchMint(wallet2, 3, 3);
    for (uint i = 3; i <= 5 && i <= _maxToReveal; i++) {
      vm.prank(wallet2);
      _pixel8_reveal(wallet2, i, "uri1");
    }

    // wallet1 - 5 points
    vm.prank(pool1);
    pixel8.batchMint(wallet1, 6, 5);
    for (uint i = 6; i <= 10 && i <= _maxToReveal; i++) {
      vm.prank(wallet1);
      _pixel8_reveal(wallet1, i, "uri1");
    }
  }
}
