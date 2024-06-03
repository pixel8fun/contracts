// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Auth } from "src/Auth.sol";
import { TestBase01 } from "test/utils/TestBase01.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { PuzzArt } from "src/PuzzArt.sol";
import { LotteryNFT } from "src/LotteryNFT.sol";
import { PoolCurve, PoolStatus } from "src/Common.sol";


abstract contract MintSwapPoolTestBase is TestBase01 {  
  MintSwapPool public pool;
  address payable pool_addr;

  function setUp() virtual public override {
    super.setUp();

    pool = new MintSwapPool(_getDefaultPoolConfig());
    pool_addr = payable(address(pool));
    
    vm.prank(owner1);
    puzzArt.setPool(pool_addr);
  }

  // Helper methods

  function _getDefaultPoolConfig() internal view returns (MintSwapPool.Config memory) {
    return MintSwapPool.Config({
      owner: owner1,
      nft: puzzArt_addr,
      curve: PoolCurve({
        mintStartId: 10,
        mintEndId: 20,
        startPriceWei: 1 gwei,
        delta: 2 * 1e18
      })
    });
  }

  function testPoolTestBase_ExcludeFromCoverage() public {}  
}
