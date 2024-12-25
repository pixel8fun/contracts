// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { MintSwapPoolTestBase } from "./MintSwapPoolTestBase.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { LibErrors } from "src/LibErrors.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { PoolCurve, PoolStatus, QuoteError, BuyQuote, SellQuote } from "src/Common.sol";

contract MintSwapPoolMulti is MintSwapPoolTestBase {
  Pixel8 public pixel8_2;
  address public pixel8_2_addr;

  function setUp() public override {
    super.setUp();

    // setup second NFT contract
    Pixel8.Config memory config = Pixel8.Config({
      owner: owner1,
      authoriser: authoriser1,
      devRoyaltyReceiver: owner1,
      devRoyaltyFeeBips: 1000, // 10%
      defaultImage: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAgMTAwIj48cmVjdCB3aWR0aD0iMTAwIiBoZWlnaHQ9IjEwMCIgZmlsbD0iYmxhY2siLz48L3N2Zz4=",
      prizePoolFeeBips: 1000, // 10%
      gameOverRevealThreshold: 100,
      forceSwapCost: 0.01 ether,
      forceSwapCooldownPeriod: 1 hours,
      externalTradeThreshold: 5
    });
    pixel8_2 = new Pixel8(config);
    pixel8_2_addr = address(pixel8_2);

    // create second pool
    vm.prank(owner1);
    pool.create(MintSwapPool.PoolConfig({
      nft: pixel8_2_addr,
      curve: PoolCurve({
        mintStartId: 10,
        mintEndId: 20,
        startPriceWei: 1 gwei,
        delta: 2 * 1e18
      })
    }));

    vm.prank(owner1);
    pixel8_2.setPool(pool_addr);
  }

  function test_Pool_MultiPool_BuySell() public {
    // Buy from first pool
    BuyQuote memory q1 = pool.getBuyQuote(pixel8_addr, 1);
    wallet1.transfer(q1.inputValue);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_addr, 1);

    // Check balances after first buy
    assertEq(pool.getFunds(pixel8_addr), q1.inputValue - q1.fee, "pool1 funds after buy1");
    assertEq(pool.getFunds(pixel8_2_addr), 0, "pool2 funds after buy1");
    assertEq(pool_addr.balance, q1.inputValue - q1.fee, "pool balance after buy1");

    // Buy from second pool
    BuyQuote memory q2 = pool.getBuyQuote(pixel8_2_addr, 1);
    wallet1.transfer(q2.inputValue);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_2_addr, 1);

    // Check balances after second buy
    assertEq(pool.getFunds(pixel8_addr), q1.inputValue - q1.fee, "pool1 funds after buy2");
    assertEq(pool.getFunds(pixel8_2_addr), q2.inputValue - q2.fee, "pool2 funds after buy2");
    assertEq(pool_addr.balance, (q1.inputValue - q1.fee) + (q2.inputValue - q2.fee), "pool balance after buy2");

    // Sell to first pool
    vm.prank(wallet1);
    pool.sell(pixel8_addr, _getTokenIdArray(1, 10));

    // Check balances after first sell
    assertEq(pool.getFunds(pixel8_addr), 0, "pool1 funds after sell1");
    assertEq(pool.getFunds(pixel8_2_addr), q2.inputValue - q2.fee, "pool2 funds after sell1");
    assertEq(pool_addr.balance, q2.inputValue - q2.fee, "pool balance after sell1");

    // Sell to second pool
    vm.prank(wallet1);
    pool.sell(pixel8_2_addr, _getTokenIdArray(1, 10));

    // Check balances after second sell
    assertEq(pool.getFunds(pixel8_addr), 0, "pool1 funds after sell2");
    assertEq(pool.getFunds(pixel8_2_addr), 0, "pool2 funds after sell2");
    assertEq(pool_addr.balance, 0, "pool balance after sell2");

    // Check NFT balances
    assertEq(pixel8.balanceOf(pool_addr), 1, "pool1 nfts");
    assertEq(pixel8_2.balanceOf(pool_addr), 1, "pool2 nfts");
    assertEq(pixel8.balanceOf(wallet1), 0, "wallet1 pool1 nfts");
    assertEq(pixel8_2.balanceOf(wallet1), 0, "wallet1 pool2 nfts");
  }

  function test_Pool_MultiPool_InsufficientFunds() public {
    // Buy from first pool
    BuyQuote memory q1 = pool.getBuyQuote(pixel8_addr, 1);
    wallet1.transfer(q1.inputValue);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_addr, 1);

    // Try to sell to second pool - should fail due to insufficient funds
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INSUFFICIENT_FUNDS));
    pool.sell(pixel8_2_addr, _getTokenIdArray(1, 10));
  }

  function test_Pool_MultiPool_BalanceCheck() public {
    // Buy multiple from first pool
    BuyQuote memory q1 = pool.getBuyQuote(pixel8_addr, 3);
    wallet1.transfer(q1.inputValue);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_addr, 3);

    // Buy multiple from second pool
    BuyQuote memory q2 = pool.getBuyQuote(pixel8_2_addr, 2);
    wallet1.transfer(q2.inputValue);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_2_addr, 2);

    // Check total balance matches sum of pool funds
    assertEq(pool_addr.balance, pool.getFunds(pixel8_addr) + pool.getFunds(pixel8_2_addr), "pool balance equals sum of funds");

    // Sell some to first pool
    vm.prank(wallet1);
    pool.sell(pixel8_addr, _getTokenIdArray(2, 10));

    // Check total balance matches sum of pool funds
    assertEq(pool_addr.balance, pool.getFunds(pixel8_addr) + pool.getFunds(pixel8_2_addr), "pool balance equals sum of funds after sell1");

    // Sell some to second pool
    vm.prank(wallet1);
    pool.sell(pixel8_2_addr, _getTokenIdArray(1, 10));

    // Check total balance matches sum of pool funds
    assertEq(pool_addr.balance, pool.getFunds(pixel8_addr) + pool.getFunds(pixel8_2_addr), "pool balance equals sum of funds after sell2");
  }
} 