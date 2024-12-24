// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { MintSwapPool } from "src/MintSwapPool.sol";
import { LibErrors } from "src/LibErrors.sol";
import { MintSwapPoolTestBase } from "./MintSwapPoolTestBase.sol";
import { PoolCurve, PoolStatus } from "src/Common.sol";

contract MintSwapPoolNftReceiver is MintSwapPoolTestBase {
  function setUp() virtual public override {
    defaultPoolConfig.curve.mintStartId = 1;
    defaultPoolConfig.curve.mintEndId = 65535;
    super.setUp();
  }

  function test_MintedNfts_AreAccepted_Fuzz(uint id) public {
    vm.assume(id >= 1);
    vm.assume(id <= 65535);

    vm.prank(pool_addr);
    pixel8.batchMint(pool_addr, id, 1);

    assertEq(pixel8.ownerOf(id), pool_addr);
  }

  function test_TransferredNfts_AreAccepted_Fuzz(uint id) public {
    vm.assume(id >= 1);
    vm.assume(id <= 65535);

    vm.prank(pool_addr);
    pixel8.batchMint(wallet1, id, 1);

    vm.prank(wallet1);
    pixel8.safeTransferFrom(wallet1, pool_addr, id);  

    assertEq(pixel8.ownerOf(id), pool_addr);
  }
}
