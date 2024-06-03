// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { LibErrors } from "src/LibErrors.sol";
import { MintSwapPoolTestBase } from "./MintSwapPoolTestBase.sol";
import { PoolCurve, PoolStatus } from "src/Common.sol";

contract MintSwapPoolEnabled is MintSwapPoolTestBase {
  function test_TogglePool_Succeeds() public {
    vm.prank(owner1);
    pool.setEnabled(true);
    assertEq(pool.enabled(), true);

    vm.prank(owner1);
    pool.setEnabled(false);
    assertEq(pool.enabled(), false);
  }

  function test_TogglePool_ByNonOwner_Fails() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, wallet1));
    pool.setEnabled(true);

    vm.prank(wallet2);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, wallet2));
    pool.setEnabled(false);
  }
}
