// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import {console2 as c} from "forge-std/Test.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { LibErrors } from "src/LibErrors.sol";


contract Pixel8PrizePool is Pixel8TestBase {
  function setUp() public override {
    defaultPixel8Config = _getDefaultPixel8Config();
    defaultPixel8Config.forceSwapConfig.cooldownPeriod = 0; // so that we can test force swap scoring

    super.setUp();

    vm.startPrank(owner1);
    pixel8.setPool(pool1);    
    vm.stopPrank();

    payable(pixel8_addr).transfer(0.0006 ether);    
  }

  function test_GetPrizePoolPot_PriorToGameOver_CalculatesBasedOnBalance() public {
    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedPrizePool = 0.0006 ether * 1000 / totalBips;
    uint pot = pixel8.getPrizesRoyaltiesWinners().prizePoolPot;
    assertEq(pot, expectedPrizePool, "getPrizePoolPot");
    
    payable(pixel8_addr).transfer(0.0006 ether);    
    pot = pixel8.getPrizesRoyaltiesWinners().prizePoolPot;
    assertEq(pot, expectedPrizePool * 2, "getPrizePoolPot");
  }

  function test_GameIsNotOverIfTileRevealThresholdNotYetReached() public {
    _mintAndRevealTiles(9);

    assertEq(pixel8.gameOver(), false, "game not over");

    payable(pixel8_addr).transfer(0.0006 ether);    

    uint expectedBalance = 0.0006 ether + 0.03 ether + 0.0006 ether;
    assertEq(address(pixel8_addr).balance, expectedBalance, "balance");

    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedPrizePoolPot = expectedBalance * 1000 / totalBips;

    assertEq(pixel8.gameOver(), false, "gameOver");
    uint pot = pixel8.getPrizesRoyaltiesWinners().prizePoolPot;
    assertEq(pot, expectedPrizePoolPot, "prize pool pot still incrementing");
    assertEq(pixel8.calculatePrize(wallet1), 0, "no prize claimable yet");    
  }

  function test_ClaimPrize_BeforeGameOver() public {
    vm.expectRevert(abi.encodeWithSelector(LibErrors.GameNotOver.selector));
    pixel8.claimPrize(wallet1);
  }

  function test_GetWinners_BeforeGameOver() public {
    _mintAndRevealTiles(9);

    uint expectedBalance = 0.0006 ether + 0.03 ether;
    assertEq(address(pixel8_addr).balance, expectedBalance, "balance");

    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedPrizePoolPot = expectedBalance * 1000 / totalBips;
    assertEq(pixel8.getPrizesRoyaltiesWinners().prizePoolPot, expectedPrizePoolPot, "prize pool pot");

    assertEq(pixel8.gameOver(), false, "gameOver");

    assertEq(pixel8.highestNumForceSwaps(), wallet5);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestThief, wallet5);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestThiefPoints, 2, "force swaps");

    assertEq(pixel8.highestTradingVolume(), wallet4); 
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestTrader, wallet4);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestTraderVolume, 0.03 ether, "trading volume");

    assertEq(pixel8.highestPoints(0), wallet1);
    assertEq(pixel8.highestPoints(1), wallet2);
    assertEq(pixel8.highestPoints(2), wallet3);

    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[0], wallet1);
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[0], 200, "1st points");
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[1], wallet2); 
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[1], 150, "2nd points");
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[2], wallet3);
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[2], 100, "3rd points");
  }

  function test_GameIsOverWhenTileRevealThresholdReached() public {
    _mintAndRevealTiles(10);

    assertEq(pixel8.gameOver(), true, "game over");

    payable(pixel8_addr).transfer(0.0006 ether);   // extra since game is already over

    uint expectedBalancePriorToGameOver = 0.0006 ether + 0.03 ether;
    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedPrizePoolPot = expectedBalancePriorToGameOver * 1000 / totalBips;
    assertEq(address(pixel8_addr).balance, expectedPrizePoolPot + 0.0006 ether, "balance");

    assertEq(pixel8.gameOver(), true, "gameOver");
    uint pot = pixel8.getPrizesRoyaltiesWinners().prizePoolPot;
    assertEq(pot, expectedPrizePoolPot, "prize pot unchanged once game over");
  }

  function test_WhenGameIsOver_HaveNoPrizesIfNotWinner() public {
    _mintAndRevealTiles(10);

    assertEq(pixel8.gameOver(), true, "game over");

    assertEq(pixel8.calculatePrize(owner1), 0, "owner1 is not a winner");
  }

  function test_WhenGameIsOver_HaveClaimablePrizes() public {
    _mintAndRevealTiles(10);

    assertEq(pixel8.gameOver(), true, "game over");

    uint expectedBalancePriorToGameOver = 0.0006 ether + 0.03 ether;
    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedPrizePoolPot = expectedBalancePriorToGameOver * 1000 / totalBips;
    assertEq(address(pixel8_addr).balance, expectedPrizePoolPot, "balance");
    
    assertEq(pixel8.highestNumForceSwaps(), wallet5);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestThief, wallet5);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestThiefPoints, 2, "force swaps");
    assertEq(pixel8.calculatePrize(wallet5), expectedPrizePoolPot * 100 / 1000);

    assertEq(pixel8.highestTradingVolume(), wallet4); 
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestTrader, wallet4);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestTraderVolume, 0.03 ether, "trading volume");
    assertEq(pixel8.calculatePrize(wallet4), expectedPrizePoolPot * 100 / 1000);

    assertEq(pixel8.highestPoints(0), wallet1);
    assertEq(pixel8.highestPoints(1), wallet2);
    assertEq(pixel8.highestPoints(2), wallet3);

    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[0], wallet1);
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[0], 250, "1st points");
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[1], wallet2); 
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[1], 150, "2nd points");
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[2], wallet3);
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[2], 100, "3rd points");
        
    assertEq(pixel8.calculatePrize(wallet1), expectedPrizePoolPot * 450 / 1000);
    assertEq(pixel8.calculatePrize(wallet2), expectedPrizePoolPot * 250 / 1000);
    assertEq(pixel8.calculatePrize(wallet3), expectedPrizePoolPot * 100 / 1000);
  }

  function test_WhenGameIsOver_Wallet1WinsAll_HaveClaimablePrizes() public {
    _mintAndRevealTilesWallet1WinsAll();

    assertEq(pixel8.gameOver(), true, "game over");

    uint expectedBalancePriorToGameOver = 0.0006 ether + 0.01 ether;
    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedPrizePoolPot = expectedBalancePriorToGameOver * 1000 / totalBips;
    assertEq(address(pixel8_addr).balance, expectedPrizePoolPot, "balance");
    
    assertEq(pixel8.highestPoints(0), wallet1);
    assertEq(pixel8.highestPoints(1), address(0));
    assertEq(pixel8.highestPoints(2), address(0));
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[0], wallet1);
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[0], 500, "1st points");
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[1], address(0)); 
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[1], 0, "2nd points");
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScorers[2], address(0));
    assertEq(pixel8.getPrizesRoyaltiesWinners().highestScores[2], 0, "3rd points");

    assertEq(pixel8.highestNumForceSwaps(), wallet1);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestThief, wallet1);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestThiefPoints, 1, "force swaps");

    assertEq(pixel8.highestTradingVolume(), wallet1); 
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestTrader, wallet1);
    assertEq(pixel8.getPrizesRoyaltiesWinners().biggestTraderVolume, 0.03 ether, "trading volume");

    assertEq(pixel8.calculatePrize(wallet1), expectedPrizePoolPot * (450 + 100 + 100) / 1000);
  }

  function test_WhenGameIsOver_CanClaimPrizeOnce() public {
    _mintAndRevealTiles(10);

    assertEq(pixel8.gameOver(), true, "game over");

    uint expectedBalancePriorToGameOver = 0.0006 ether + 0.03 ether;
    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedPrizePoolPot = expectedBalancePriorToGameOver * 1000 / totalBips;
    assertEq(address(pixel8_addr).balance, expectedPrizePoolPot, "balance");

    uint claimableExpected = expectedPrizePoolPot * 450 / 1000;

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
    // wallet3 - 100 points
    vm.prank(pool1);
    pixel8.batchMint(wallet3, 1, 2);
    for (uint i = 1; i <= 2 && i <= _maxToReveal; i++) {
      _pixel8_reveal(wallet3, i, "uri1");
    }

    // wallet2 - 150 points
    vm.prank(pool1);
    pixel8.batchMint(wallet2, 3, 3);
    for (uint i = 3; i <= 5 && i <= _maxToReveal; i++) {
      _pixel8_reveal(wallet2, i, "uri1");
    }

    // wallet1 - 250 points
    vm.prank(pool1);
    pixel8.batchMint(wallet1, 6, 5);

    // wallet5 - does most force swaps
    vm.startPrank(wallet2);
    pixel8.batchTransferRange(wallet2, wallet5, 2); // give two tiles to wallet5
    vm.deal(wallet2, 0.01 ether);
    pixel8.forceSwap{value: 0.01 ether}(3, 1); // force swap one tile
    vm.stopPrank();
    vm.startPrank(wallet5);
    vm.deal(wallet5, 0.02 ether);
    pixel8.forceSwap{value: 0.01 ether}(4, 1); // force swap 1 tile
    pixel8.forceSwap{value: 0.01 ether}(5, 2); // force swap 1 tile
    vm.stopPrank();

    // record trade volume
    vm.startPrank(pool1);
    pixel8.recordTrade(wallet1, 0.01 ether, true, 1);
    pixel8.recordTrade(wallet4, 0.03 ether, true, 1); // wallet4 is the highest trading volume
    pixel8.recordTrade(wallet2, 0.02 ether, true, 1);
    vm.stopPrank();

    assertEq(pixel8.gameOver(), false, "game not yet over");

    // reveal the remaining tiles
    for (uint i = 6; i <= 10 && i <= _maxToReveal; i++) {
      _pixel8_reveal(wallet1, i, "uri1");
    }
  }

  function _mintAndRevealTilesWallet1WinsAll() internal {
    vm.startPrank(pool1);
    pixel8.batchMint(wallet1, 1, 9);
    pixel8.batchMint(wallet2, 10, 1);
    vm.stopPrank();

    for (uint i = 1; i <= 9; i++) {
      _pixel8_reveal(wallet1, i, "uri1");
    }

    // trade volume
    vm.prank(pool1);
    pixel8.recordTrade(wallet1, 0.03 ether, true, 1);

    // force swaps
    vm.deal(wallet1, 0.01 ether);
    vm.prank(wallet1);
    pixel8.forceSwap{value: 0.01 ether}(1, 10);

    assertEq(pixel8.gameOver(), false, "game not yet over");
    _pixel8_reveal(wallet1, 10, "uri1");
    assertEq(pixel8.gameOver(), true, "game over");
  }
}
