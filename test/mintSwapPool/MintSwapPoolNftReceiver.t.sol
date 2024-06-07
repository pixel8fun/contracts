// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { MintSwapPool } from "src/MintSwapPool.sol";
import { LibErrors } from "src/LibErrors.sol";
import { MintSwapPoolTestBase } from "./MintSwapPoolTestBase.sol";
import { PoolCurve, PoolStatus } from "src/Common.sol";

contract MintSwapPoolNftReceiver is MintSwapPoolTestBase {
  function test_MintedNfts_AreAccepted_Fuzz(uint id) public {
    vm.prank(pool_addr);
    _pixel8_mint(pool_addr, id, "", 0);

    assertEq(pixel8.ownerOf(id), pool_addr);
  }

  function test_TransferredNfts_AreAccepted_Fuzz(uint id) public {
    vm.startPrank(wallet1);

    _pixel8_mint(wallet1, id, "", 0);
    pixel8.safeTransferFrom(wallet1, pool_addr, id);  
    
    vm.stopPrank();

    assertEq(pixel8.ownerOf(id), pool_addr);
  }
}
