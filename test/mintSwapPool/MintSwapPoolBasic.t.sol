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

  function test_MintPrice_Fuzz(uint128 price) public {
    vm.assume(price >= 1 gwei);

    pool = new MintSwapPool(owner1);
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

  function test_MintPrice_Bad() public {
    uint128 price = 1 gwei - 1;

    pool = new MintSwapPool(owner1);
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

  function test_MintRange_Fuzz(uint start, uint end) public {
    vm.assume(start > 1);
    vm.assume(end >= start);

    pool = new MintSwapPool(owner1);
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

  function test_MintRange_Bad() public {
    pool = new MintSwapPool(owner1);
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

  function test_PoolAlreadyExists() public {
    vm.prank(owner1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.PoolAlreadyExists.selector, pixel8_addr));
    pool.create(_getDefaultPoolConfig());
  }
}
