// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { LibErrors } from "src/LibErrors.sol";
import { MintSwapPoolTestBase } from "./MintSwapPoolTestBase.sol";
import { PoolCurve, PoolStatus } from "src/Common.sol";

contract MintSwapPoolBasic is MintSwapPoolTestBase {
  function test_Pool_DefaultConfig() public {
    (PoolCurve memory c, PoolStatus memory s) = pool.getCurveStatus(pixel8_addr);
    assertEq(c.mintStartId, 10);
    assertEq(c.mintEndId, 20);
    assertEq(c.startPriceWei, 1 gwei);
    assertEq(c.delta, 2 * 1e18);

    assertEq(s.lastMintId, 9);
    assertEq(s.priceWei, 1 gwei);
  }

  function test_Pool_MintPrice_Fuzz(uint128 price) public {
    vm.assume(price >= 1 gwei);

    pool = new MintSwapPool(owner1, owner1);
    vm.prank(owner1);
    pool.create(MintSwapPool.PoolConfig({
      nft: pixel8_addr,
      curve: PoolCurve({
        mintStartId: 1,
        mintEndId: 1,
        startPriceWei: price,
        delta: 2 * 1e18
      })
    }));
  }

  function test_Pool_MintPrice_Bad() public {
    uint128 price = 1 gwei - 1;

    pool = new MintSwapPool(owner1, owner1);
    vm.prank(owner1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidMintPrice.selector, price));
    pool.create(MintSwapPool.PoolConfig({
      nft: pixel8_addr,
      curve: PoolCurve({
        mintStartId: 1,
        mintEndId: 1,
        startPriceWei: price,
        delta: 2 * 1e18
      })
    }));
  }

  function test_Pool_MintRange_Fuzz(uint start, uint end) public {
    vm.assume(start > 1);
    vm.assume(end >= start);

    pool = new MintSwapPool(owner1, owner1);
    vm.prank(owner1);
    pool.create(MintSwapPool.PoolConfig({
      nft: pixel8_addr,
      curve: PoolCurve({
        mintStartId: start,
        mintEndId: end,
        startPriceWei: 1 gwei,
        delta: 2 * 1e18
      })
    }));
  }

  function test_Pool_MintRange_Bad() public {
    pool = new MintSwapPool(owner1, owner1);
    vm.startPrank(owner1);

    vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidMintStartId.selector, 0));
    pool.create(MintSwapPool.PoolConfig({
      nft: pixel8_addr,
      curve: PoolCurve({
        mintStartId: 0,
        mintEndId: 1,
        startPriceWei: 1 gwei,
        delta: 2 * 1e18
      })
    }));

    vm.expectRevert(abi.encodeWithSelector(LibErrors.InvalidMintEndId.selector, 1));
    pool.create(MintSwapPool.PoolConfig({
      nft: pixel8_addr,
      curve: PoolCurve({
        mintStartId: 2,
        mintEndId: 1,
        startPriceWei: 1 gwei,
        delta: 2 * 1e18
      })
    }));

    vm.stopPrank();
  }

  function test_Pool_AlreadyExists() public {
    vm.prank(owner1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.PoolAlreadyExists.selector, pixel8_addr));
    pool.create(_getDefaultPoolConfig());
  }

  function test_Pool_Creator() public {
    // Test initial pool creator from constructor
    assertEq(pool.poolCreator(), owner1);

    // Test setting new pool creator
    vm.prank(owner1);
    pool.setPoolCreator(wallet1);
    assertEq(pool.poolCreator(), wallet1);

    // Test that old pool creator can't create pools
    vm.prank(owner1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.Unauthorized.selector, owner1));
    pool.create(_getDefaultPoolConfig());

    // Test that new pool creator can create pools
    vm.prank(wallet1);
    pool.create(MintSwapPool.PoolConfig({
      nft: address(0x123),
      curve: PoolCurve({
        mintStartId: 1,
        mintEndId: 10,
        startPriceWei: 1 gwei,
        delta: 2 * 1e18
      })
    }));

    // Test that non-owner can't set pool creator
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, wallet1));
    pool.setPoolCreator(wallet1);
  }
}
