// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { console2 as c } from "forge-std/Test.sol";
import { MintSwapPoolTestBase } from "./MintSwapPoolTestBase.sol";
import { LibErrors } from "src/LibErrors.sol";
import { IERC721Errors } from "src/IERC721Errors.sol";
import { PoolCurve, PoolStatus, QuoteError, BuyQuote, SellQuote } from "src/Common.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

contract MintSwapPoolTrading is MintSwapPoolTestBase {
  using FixedPointMathLib for uint256;

  // getTotalNftsForSale - initial

  function test_Pool_GetTotalNftsForSale_Initial() public view {
    assertEq(pool.getTotalNftsForSale(pixel8_addr), 11);
  }

  // getBuyQuote - initial

  function test_Pool_GetBuyQuote_Initial_BuyOne() public view {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 1);
    assertEq(uint(q.error), uint(QuoteError.NONE));
    assertEq(q.newSpotPrice, 2 gwei);

    uint inputValue = 2 gwei;
    uint fee = inputValue * 25 / 100; // 25%

    assertEq(q.fee, fee);
    assertEq(q.inputValue, inputValue + fee);
  }

  function test_Pool_GetBuyQuote_Initial_BuyAll() public view {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 11);
    assertEq(uint(q.error), uint(QuoteError.NONE), "error code");
    assertEq(q.newSpotPrice, 2048 gwei /* 2^11 */, "new spot price");

    uint inputValue = 
      2 gwei +
      4 gwei +
      8 gwei +
      16 gwei +
      32 gwei +
      64 gwei +
      128 gwei +
      256 gwei +
      512 gwei +
      1024 gwei +
      2048 gwei; // 4094 gwei

    uint fee = inputValue * 25 / 100; // 25%

    assertEq(q.fee, fee, "fee");
    assertEq(q.inputValue, inputValue + fee, "total");
  }

  function test_Pool_GetBuyQuote_Initial_BuyTooMuch() public view {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 12);
    assertEq(uint(q.error), uint(QuoteError.INSUFFICIENT_NFTS));
  }

  function test_Pool_GetBuyQuote_Initial_BuyNone() public view {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 0);
    assertEq(uint(q.error), uint(QuoteError.INVALID_NUMITEMS));
  }

  function test_Pool_GetBuyQuote_Initial_NewSpotPriceOverflow() public view {
    // 2^63    
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 100);
    assertEq(uint(q.error), uint(QuoteError.SPOT_PRICE_OVERFLOW));
  }

  // buy - initial

  function test_Pool_Buy_Initial_BuyOne() public {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 1);

    wallet1.transfer(q.inputValue); // exact funds
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_addr, 1);

    // check NFTs minted
    assertEq(pixel8.totalSupply(), 1, "nft supply");
    assertEq(pixel8.tokenByIndex(0), 10, "token at index 0");

    // check caller funds
    assertEq(wallet1.balance, 0, "caller funds");
    // check caller nfts
    assertEq(pixel8.balanceOf(wallet1), 1, "nft balance");
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 0), 10, "token of owner at index 0");

    // check pool NFTs
    assertEq(pixel8.balanceOf(pool_addr), 0, "pool nfts");
    assertEq(pool.getTotalNftsForSale(pixel8_addr), 10, "pool nfts for sale");
    // check pool funds
    assertEq(pool_addr.balance, q.inputValue - q.fee, "pool funds");
    assertEq(pool.getFunds(pixel8_addr), q.inputValue - q.fee, "pool.getFunds");
    
    // check fee receiver funds
    assertEq(pixel8_addr.balance, q.fee, "received fee");

    // check trade volume
    assertEq(gameStats.tradingVolume(pixel8_addr, wallet1), q.inputValue, "trade volume");
  }

    function test_Pool_Buy_Initial_BuyAll() public {
      BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 11);

    wallet1.transfer(1 ether);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_addr, 11);

    // check NFTs minted
    assertEq(pixel8.totalSupply(), 11, "nft supply");
    assertEq(pixel8.tokenByIndex(0), 10, "token at index 0");
    assertEq(pixel8.tokenByIndex(1), 11, "token at index 1");
    assertEq(pixel8.tokenByIndex(10), 20, "token at index 10");

    // check caller funds
    assertEq(wallet1.balance, 1 ether - q.inputValue);
    // check caller nfts
    assertEq(pixel8.balanceOf(wallet1), 11);
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 0), 10, "token of owner at index 0");
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 1), 11, "token of owner at index 1");
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 10), 20, "token of owner at index 10");

    // check pool NFTs
    assertEq(pixel8.balanceOf(pool_addr), 0, "post: pool NFTs");
    assertEq(pool.getTotalNftsForSale(pixel8_addr), 0, "post: pool nfts for sale");
    // check pool funds
    assertEq(pool_addr.balance, q.inputValue - q.fee, "post: pool funds");
    assertEq(pool.getFunds(pixel8_addr), q.inputValue - q.fee, "post: pool.getFunds");

    // check fee receiver funds
    assertEq(pixel8_addr.balance, q.fee, "post: received fee");

    // check trade volume
    assertEq(gameStats.tradingVolume(pixel8_addr, wallet1), q.inputValue, "post: trade volume");
  }

  function test_Pool_Buy_Initial_BuyOne_InsufficientFunds() public {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 1);

    wallet1.transfer(q.inputValue - 1);
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.InsufficientSenderFunds.selector, wallet1, q.inputValue, wallet1.balance));
    pool.buy{value: wallet1.balance}(pixel8_addr, 1);
  }

  function test_Pool_Buy_Initial_BuyOne_TooMuchFunds() public {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 1);

    wallet1.transfer(q.inputValue + 1);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_addr, 1);

    // check caller funds to ensure extra got returned
    assertEq(wallet1.balance, 1);
  }

  function test_Pool_Buy_Initial_BuyTooMuch() public {
    wallet1.transfer(1 ether);
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INSUFFICIENT_NFTS));
    pool.buy{value: wallet1.balance}(pixel8_addr, 12);
  }

  function test_Pool_Buy_Initial_BuyNone() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INVALID_NUMITEMS));
    pool.buy{value: wallet1.balance}(pixel8_addr, 0);
  }

  function test_Pool_Buy_Initial_BuyCrazy_SpotPriceOverflow() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.SPOT_PRICE_OVERFLOW));
    pool.buy{value: wallet1.balance}(pixel8_addr, 100);
  }

  // buy - specific

  function test_Pool_BuySpecific_NotYetMinted() public {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 1);

    wallet1.transfer(q.inputValue); // exact funds
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, pool_addr, uint(10)));    
    pool.buySpecific{value: wallet1.balance}(pixel8_addr, 10);
  }

  function test_Pool_BuySpecific_NotInPool() public {
    _buySomeNfts(1, 2 gwei);

    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 1);

    wallet1.transfer(q.inputValue); // exact funds
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, pool_addr, uint(10)));    
    pool.buySpecific{value: wallet1.balance}(pixel8_addr, 10);
  }

  function test_Pool_BuySpecific_Succeeds() public {
    BuyQuote memory _q1 = _buySomeNfts(1, 2 gwei);
    SellQuote memory _q2 = _sellSomeNfts(_getTokenIdArray(1, 10), 1 gwei);

    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, 1);

    wallet1.transfer(q.inputValue - wallet1.balance); // exact funds
    vm.prank(wallet1);
    pool.buySpecific{value: wallet1.balance}(pixel8_addr, 10);

    // check NFTs minted
    assertEq(pixel8.totalSupply(), 1, "nft supply");
    assertEq(pixel8.tokenByIndex(0), 10, "token at index 0");

    // check caller funds
    assertEq(wallet1.balance, 0, "caller funds");
    // check caller nfts
    assertEq(pixel8.balanceOf(wallet1), 1, "nft balance");
    assertEq(pixel8.tokenOfOwnerByIndex(wallet1, 0), 10, "token of owner at index 0");

    // check pool NFTs
    assertEq(pixel8.balanceOf(pool_addr), 0, "pool nfts");
    assertEq(pool.getTotalNftsForSale(pixel8_addr), 10, "pool nfts for sale");
    // check pool funds
    assertEq(pool_addr.balance, q.inputValue - q.fee, "pool funds");
    assertEq(pool.getFunds(pixel8_addr), q.inputValue - q.fee, "pool.getFunds");
    
    // check fee receiver funds
    assertEq(pixel8_addr.balance, q.fee * 3, "received fee");

    // check trade volume
    assertEq(gameStats.tradingVolume(pixel8_addr, wallet1), _q1.inputValue + _q2.outputValue + q.inputValue, "post: trade volume");
  }

  // getSellQuote

  function test_Pool_GetSellQuote_SellOne() public {
    _buySomeNfts(1, 2 gwei);

    SellQuote memory q = pool.getSellQuote(pixel8_addr, 1);
    assertEq(uint(q.error), uint(QuoteError.NONE), "error code");
    assertEq(q.newSpotPrice, 1 gwei, "new spot price");

    uint outputValue = 2 gwei;
    uint fee = outputValue * 25 / 100; // 25%

    assertEq(q.fee, fee, "fee");
    assertEq(q.outputValue, outputValue - fee, "output value");
  }

  function test_Pool_GetSellQuote_SellAll() public {
    _buySomeNfts(11, 2048 gwei);

    SellQuote memory q = pool.getSellQuote(pixel8_addr, 11);
    assertEq(uint(q.error), uint(QuoteError.NONE), "error code");
    assertEq(q.newSpotPrice, 1 gwei, "new spot price");

    uint outputValue = 
      2048 gwei +
      1024 gwei +
      512 gwei +
      256 gwei +
      128 gwei +
      64 gwei +
      32 gwei +
      16 gwei +
      8 gwei +
      4 gwei +
      2 gwei; // 4094 gwei

    uint fee = outputValue * 25 / 100; // 25%

    assertEq(q.fee, fee, "fee");
    assertEq(q.outputValue, outputValue - fee, "output value");
  }

  function test_Pool_GetSellQuote_SellNone() public view {
    SellQuote memory q = pool.getSellQuote(pixel8_addr, 0);
    assertEq(uint(q.error), uint(QuoteError.INVALID_NUMITEMS));
  }

  // sell

  function test_Sell_SellOne() public {
    BuyQuote memory _q1 = _buySomeNfts(1, 2 gwei);

    SellQuote memory q = pool.getSellQuote(pixel8_addr, 1);

    vm.prank(wallet1);
    pool.sell(pixel8_addr, _getTokenIdArray(1, 10));

    // check caller funds
    assertEq(wallet1.balance, q.outputValue, "caller funds");
    // check caller nfts
    assertEq(pixel8.balanceOf(wallet1), 0, "nft balance");

    // check pool NFTs
    assertEq(pixel8.balanceOf(pool_addr), 1, "pool nfts");
    assertEq(pool.getTotalNftsForSale(pixel8_addr), 11, "pool nfts for sale");
    // check pool funds
    assertEq(pool_addr.balance, 0, "pool funds");
    assertEq(pool.getFunds(pixel8_addr), 0, "pool.getFunds");

    // check fee receiver funds
    assertEq(pixel8_addr.balance, q.fee * 2, "received fee");

    // check trade volume
    assertEq(gameStats.tradingVolume(pixel8_addr, wallet1), _q1.inputValue + q.outputValue, "post: trade volume");
  }

  function test_Sell_SellAll() public {
    BuyQuote memory _q1 = _buySomeNfts(11, 2048 gwei);

    SellQuote memory q = pool.getSellQuote(pixel8_addr, 11);

    vm.prank(wallet1);
    pool.sell(pixel8_addr, _getTokenIdArray(11, 10));

    // check caller funds
    assertEq(wallet1.balance, q.outputValue, "caller funds");
    // check caller nfts
    assertEq(pixel8.balanceOf(wallet1), 0, "nft balance");

    // check pool NFTs
    assertEq(pixel8.balanceOf(pool_addr), 11, "pool nfts");
    assertEq(pool.getTotalNftsForSale(pixel8_addr), 11, "pool nfts for sale");
    // check pool funds
    assertEq(pool_addr.balance, 0, "pool funds");
    assertEq(pool.getFunds(pixel8_addr), 0, "pool.getFunds");

    // check fee receiver funds
    assertEq(pixel8_addr.balance, q.fee * 2, "received fee");

    // check trade volume
    assertEq(gameStats.tradingVolume(pixel8_addr, wallet1), _q1.inputValue + q.outputValue, "post: trade volume");
  }

  function test_Sell_SellNone() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INVALID_NUMITEMS));
    pool.sell(pixel8_addr, new uint[](0));
  }

  function test_Sell_InsufficientNfts() public {
    _buySomeNfts(1, 2 gwei);

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INSUFFICIENT_FUNDS));
    pool.sell(pixel8_addr, _getTokenIdArray(2, 10));
  }

  function test_Sell_InsufficientFunds() public {
    _buySomeNfts(1, 2 gwei);

    // remove funds from pool
    vm.prank(pool_addr);
    payable(owner1).transfer(pool_addr.balance);

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INSUFFICIENT_FUNDS));
    pool.sell(pixel8_addr, _getTokenIdArray(1, 10));
  }

  // Helper methods

  function _buySomeNfts(uint numItems, uint expectedPrice) private returns (BuyQuote memory) {
    BuyQuote memory q = pool.getBuyQuote(pixel8_addr, numItems);
    assertEq(q.newSpotPrice, expectedPrice);

    wallet1.transfer(q.inputValue);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(pixel8_addr, numItems);
    assertEq(wallet1.balance, 0, "post buy:wallet1 balance");

    return q;
  }

  function _sellSomeNfts(uint[] memory tokenIds, uint expectedPrice) private returns (SellQuote memory) {
    SellQuote memory q = pool.getSellQuote(pixel8_addr, tokenIds.length);
    assertEq(q.newSpotPrice, expectedPrice);

    vm.prank(wallet1);
    pool.sell(pixel8_addr, tokenIds);
    assertEq(wallet1.balance, q.outputValue, "post sale: wallet1 balance");

    return q;
  }
}


