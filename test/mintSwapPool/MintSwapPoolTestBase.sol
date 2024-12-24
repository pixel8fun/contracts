// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Auth } from "src/Auth.sol";
import { TestBase01 } from "test/utils/TestBase01.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { PoolCurve, PoolStatus } from "src/Common.sol";


abstract contract MintSwapPoolTestBase is TestBase01 {  
  MintSwapPool public pool;
  address payable pool_addr;

  function setUp() virtual public override {
    super.setUp();

    pool = new MintSwapPool(owner1);
    pool_addr = payable(address(pool));
    
    vm.startPrank(owner1);
    pool.create(_getDefaultPoolConfig());
    pixel8.setPool(pool_addr);
    vm.stopPrank();
  }

  // Helper methods

  function _getDefaultPoolConfig() internal view returns (MintSwapPool.PoolConfig memory) {
    return MintSwapPool.PoolConfig({
      nft: pixel8_addr,
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
