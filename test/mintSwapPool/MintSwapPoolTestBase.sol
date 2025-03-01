// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { console2 as c } from "forge-std/Test.sol";
import { Auth } from "src/Auth.sol";
import { TestBase01 } from "test/utils/TestBase01.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { IMintSwapPool } from "src/IMintSwapPool.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { PoolCurve, PoolStatus } from "src/Common.sol";


abstract contract MintSwapPoolTestBase is TestBase01 {  
  IMintSwapPool.PoolConfig public defaultPoolConfig;
  MintSwapPool public pool;
  address payable pool_addr;

  function setUp() virtual public override {
    super.setUp();

    if (defaultPoolConfig.nft == address(0)) {
      defaultPoolConfig = _getDefaultPoolConfig();
    }

    pool = new MintSwapPool(owner1, owner1);
    pool_addr = payable(address(pool));
    
    vm.startPrank(owner1);
    pool.create(defaultPoolConfig);
    pixel8.setPool(pool_addr);
    gameStats.setPool(pool_addr);
    vm.stopPrank();
  }

  // Helper methods

  function _getDefaultPoolConfig() internal view returns (IMintSwapPool.PoolConfig memory) {
    return IMintSwapPool.PoolConfig({
      nft: pixel8_addr,
      curve: PoolCurve({
        mintStartId: 10,
        mintEndId: 20,
        startPriceWei: 1 gwei,
        delta: 2 * 1e18
      })
    });
  }

  function _getTokenIdArray(uint numItems, uint firstId) internal pure returns (uint[] memory) {
    uint[] memory tokenIds = new uint[](numItems);
    for (uint i = 0; i < numItems; i++) {
      tokenIds[i] = firstId + i;
    }
    return tokenIds;
  }

  function testPoolTestBase_ExcludeFromCoverage() public {}  
}
