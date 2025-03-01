// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { LibErrors } from "src/LibErrors.sol";
import { Pixel8TestBase } from "./Pixel8TestBase.sol";

contract Pixel8Royalties is Pixel8TestBase {
  function setUp() public override {
    super.setUp();

    vm.startPrank(owner1);
    pixel8.setPool(pool1);
    gameStats.setPool(pool1); 
    vm.stopPrank();
  }

  function test_DefaultRoyaltyConfig() public {
    Pixel8.Royalties memory devRoyalties = pixel8.getDevRoyaltyConfig();
    assertEq(devRoyalties.feeBips, 1000, "devRoyalties.feeBips");
    assertEq(devRoyalties.receiver, owner1, "devRoyalties.receiver");

    Pixel8.Royalties memory creatorRoyalties = pixel8.getCreatorRoyaltyConfig();
    assertEq(creatorRoyalties.feeBips, 500, "creatorRoyalties.feeBips");
    assertEq(creatorRoyalties.receiver, creator1, "creatorRoyalties.receiver");

    (address receiver, uint256 fee) = pixel8.royaltyInfo(0, 100);
    assertEq(receiver, pixel8_addr, "royaltyInfo.receiver");
    assertEq(fee, 25, "royaltyInfo.fee"); // (1000 + 500 + 1000) bips = 2500 = 25%

    (address rec, uint256 feeBips) = pixel8.getRoyaltyInfo();
    assertEq(rec, pixel8_addr, "getRoyaltyInfo.receiver");
    assertEq(feeBips, 2500, "getRoyaltyInfo.fee"); // 1000 + 500 + 1000 bips
  }

  function test_RoyaltyDistributionBeforeGameOver() public {
    payable(pixel8_addr).transfer(1 ether);

    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedDevRoyalties = 1 ether * 1000 / totalBips; // 0.4 ether
    uint expectedCreatorRoyalties = 1 ether * 500 / totalBips; // 0.2 ether
    uint expectedPrizePool = 1 ether * 1000 / totalBips; // 0.4 ether

    Pixel8.RoyaltiesPrizes memory royaltiesPrizes = pixel8.getRoyaltiesPrizes();
    assertEq(royaltiesPrizes.prizePoolPot, expectedPrizePool, "prize pool pot");
    assertEq(royaltiesPrizes.devRoyaltiesPot, expectedDevRoyalties, "dev royalties");
    assertEq(royaltiesPrizes.creatorRoyaltiesPot, expectedCreatorRoyalties, "creator royalties");
  }

  function test_RoyaltyDistributionAfterGameOver() public {
    payable(pixel8_addr).transfer(1 ether);
    
    uint balanceBeforeDev = owner1.balance;
    uint balanceBeforeCreator = creator1.balance;

    _mintAndRevealTiles(10); // Trigger game over

    uint totalBips = 2500; // 1000 (dev) + 500 (creator) + 1000 (prize pool)
    uint expectedDevRoyalties = 1 ether * 1000 / totalBips; // 0.4 ether
    uint expectedCreatorRoyalties = 1 ether * 500 / totalBips; // 0.2 ether
    uint expectedPrizePool = 1 ether * 1000 / totalBips; // 0.4 ether

    assertEq(owner1.balance - balanceBeforeDev, expectedDevRoyalties, "dev royalties paid");
    assertEq(creator1.balance - balanceBeforeCreator, expectedCreatorRoyalties, "creator royalties paid");
    Pixel8.RoyaltiesPrizes memory royaltiesPrizes = pixel8.getRoyaltiesPrizes();
    assertEq(royaltiesPrizes.prizePoolPot, expectedPrizePool, "prize pool pot");
    assertEq(royaltiesPrizes.devRoyaltiesPot, expectedDevRoyalties, "dev royalties");
    assertEq(royaltiesPrizes.creatorRoyaltiesPot, expectedCreatorRoyalties, "creator royalties");

    // After game over, royalties should only go to dev
    (address receiver, uint256 feeBips) = pixel8.getRoyaltyInfo();
    assertEq(receiver, owner1, "royaltyInfo.receiver after game over");
    assertEq(feeBips, 1000, "royaltyInfo.fee after game over");
  }

  // Helper method to mint and reveal tiles
  function _mintAndRevealTiles(uint _maxToReveal) internal {
    vm.prank(pool1);
    pixel8.batchMint(wallet1, 1, _maxToReveal);
    for (uint i = 1; i <= _maxToReveal; i++) {
      _pixel8_reveal(wallet1, i, "uri1");
    }
  }
} 