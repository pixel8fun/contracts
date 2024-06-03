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

  function test_GetTotalNftsForSale_Initial() public {
    assertEq(pool.getTotalNftsForSale(), 11);
  }

  // getBuyQuote - initial

  function test_GetBuyQuote_Initial_BuyOne() public {
    BuyQuote memory q = pool.getBuyQuote(1);
    assertEq(uint(q.error), uint(QuoteError.NONE));
    assertEq(q.newSpotPrice, 2 gwei);

    uint inputValue = 2 gwei;
    uint fee = inputValue / 5; // 20%

    assertEq(q.fee, fee);
    assertEq(q.inputValue, inputValue + fee);
  }

  function test_GetBuyQuote_Initial_BuyAll() public {
    BuyQuote memory q = pool.getBuyQuote(11);
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

    uint fee = inputValue / 5; // 20%

    assertEq(q.fee, fee, "fee");
    assertEq(q.inputValue, inputValue + fee, "total");
  }

  function test_GetBuyQuote_Initial_BuyTooMuch() public {
    BuyQuote memory q = pool.getBuyQuote(12);
    assertEq(uint(q.error), uint(QuoteError.INSUFFICIENT_NFTS));
  }

  function test_GetBuyQuote_Initial_BuyNone() public {
    BuyQuote memory q = pool.getBuyQuote(0);
    assertEq(uint(q.error), uint(QuoteError.INVALID_NUMITEMS));
  }

  function test_GetBuyQuote_Initial_NewSpotPriceOverflow() public {
    // 2^63    
    BuyQuote memory q = pool.getBuyQuote(100);
    assertEq(uint(q.error), uint(QuoteError.SPOT_PRICE_OVERFLOW));
  }

  // buy - initial

  function test_Buy_WhenTradingDisabled() public {
    vm.prank(owner1);
    pool.setEnabled(false);

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.TradingDisabled.selector));
    pool.buy(1);
  }

  function test_Buy_Initial_BuyOne() public {
    BuyQuote memory q = pool.getBuyQuote(1);

    wallet1.transfer(q.inputValue); // exact funds
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(1);

    // check NFTs minted
    assertEq(puzzArt.totalSupply(), 1, "nft supply");
    assertEq(puzzArt.tokenByIndex(0), 10, "token at index 0");

    // check caller funds
    assertEq(wallet1.balance, 0, "caller funds");
    // check caller nfts
    assertEq(puzzArt.balanceOf(wallet1), 1, "nft balance");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 10, "token of owner at index 0");

    // check pool NFTs
    assertEq(puzzArt.balanceOf(pool_addr), 0, "pool nfts");
    assertEq(pool.getTotalNftsForSale(), 10, "pool nfts for sale");
    // check pool funds
    assertEq(pool_addr.balance, q.inputValue - q.fee, "pool funds");
    assertEq(pool.getFunds(), q.inputValue - q.fee, "poolotteryNft.getFunds");
    
    // check fee receiver funds
    assertEq(puzzArt_addr.balance, q.fee, "received fee");
  }

  function test_Buy_Initial_BuyAll() public {
    BuyQuote memory q = pool.getBuyQuote(11);

    wallet1.transfer(1 ether);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(11);

    // check NFTs minted
    assertEq(puzzArt.totalSupply(), 11, "nft supply");
    assertEq(puzzArt.tokenByIndex(0), 10, "token at index 0");
    assertEq(puzzArt.tokenByIndex(1), 11, "token at index 1");
    assertEq(puzzArt.tokenByIndex(10), 20, "token at index 10");

    // check caller funds
    assertEq(wallet1.balance, 1 ether - q.inputValue);
    // check caller nfts
    assertEq(puzzArt.balanceOf(wallet1), 11);
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 10, "token of owner at index 0");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 1), 11, "token of owner at index 1");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 10), 20, "token of owner at index 10");

    // check pool NFTs
    assertEq(puzzArt.balanceOf(pool_addr), 0, "post: pool NFTs");
    assertEq(pool.getTotalNftsForSale(), 0, "post: pool nfts for sale");
    // check pool funds
    assertEq(pool_addr.balance, q.inputValue - q.fee, "post: pool funds");
    assertEq(pool.getFunds(), q.inputValue - q.fee, "post: poolotteryNft.getFunds");

    // check fee receiver funds
    assertEq(puzzArt_addr.balance, q.fee, "post: received fee");
  }

  function test_Buy_Initial_BuyOne_InsufficientFunds() public {
    BuyQuote memory q = pool.getBuyQuote(1);

    wallet1.transfer(q.inputValue - 1);
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.InsufficientSenderFunds.selector, wallet1, q.inputValue, wallet1.balance));
    pool.buy{value: wallet1.balance}(1);
  }

  function test_Buy_Initial_BuyOne_TooMuchFunds() public {
    BuyQuote memory q = pool.getBuyQuote(1);

    wallet1.transfer(q.inputValue + 1);
    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(1);

    // check caller funds to ensure extra got returned
    assertEq(wallet1.balance, 1);
  }

  function test_Buy_Initial_BuyTooMuch() public {
    wallet1.transfer(1 ether);
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INSUFFICIENT_NFTS));
    pool.buy{value: wallet1.balance}(12);
  }

  function test_Buy_Initial_BuyNone() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INVALID_NUMITEMS));
    pool.buy{value: wallet1.balance}(0);
  }

  function test_Buy_Initial_BuyCrazy_SpotPriceOverflow() public {
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.SPOT_PRICE_OVERFLOW));
    pool.buy{value: wallet1.balance}(100);
  }

  // getSellQuote

  function test_GetSellQuote_SellOne() public {
    _buySomeNfts(1, 2 gwei);

    SellQuote memory q = pool.getSellQuote(1);
    assertEq(uint(q.error), uint(QuoteError.NONE), "error code");
    assertEq(q.newSpotPrice, 1 gwei, "new spot price");

    uint outputValue = 2 gwei;
    uint fee = outputValue / 5; // 20%

    assertEq(q.fee, fee, "fee");
    assertEq(q.outputValue, outputValue - fee, "output value");
  }

  function test_GetSellQuote_SellAll() public {
    _buySomeNfts(11, 2048 gwei);

    SellQuote memory q = pool.getSellQuote(11);
    assertEq(uint(q.error), uint(QuoteError.NONE), "error code");
    assertEq(q.newSpotPrice, 1 gwei, "new spot price");

    uint outputValue = 
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

    uint fee = outputValue / 5; // 20%

    assertEq(q.fee, fee, "fee");
    assertEq(q.outputValue, outputValue - fee, "output value");
  }

  function test_GetSellQuote_SellTooMuch() public {
    _buySomeNfts(1, 2 gwei);

    SellQuote memory q = pool.getSellQuote(2);
    assertEq(uint(q.error), uint(QuoteError.INSUFFICIENT_FUNDS), "error code");
  }

  function test_GetSellQuote_SellNone() public {
    _buySomeNfts(1, 2 gwei);

    SellQuote memory q = pool.getSellQuote(0);
    assertEq(uint(q.error), uint(QuoteError.INVALID_NUMITEMS), "error code");
  }

  // sell

  function test_Sell_WhenTradingDisabled() public {
    vm.prank(owner1);
    pool.setEnabled(false);

    uint[] memory ids = new uint[](1);
    ids[0] = 10;

    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.TradingDisabled.selector));
    pool.sell(ids);
  }

  function test_Sell_SellOne() public {
    _buySomeNfts(1, 2 gwei);

    SellQuote memory q = pool.getSellQuote(1);

    uint[] memory ids = new uint[](1);
    ids[0] = 10;

    vm.prank(wallet1);
    pool.sell(ids);

    // check caller funds
    assertEq(wallet1.balance, q.outputValue, "caller funds");
    // check caller nfts
    assertEq(puzzArt.balanceOf(wallet1), 0, "caller nfts");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 0, "token of owner at index 0");

    // check pool NFTs
    assertEq(pool.getTotalNftsForSale(), 11, "pool nfts for sale");
    assertEq(puzzArt.balanceOf(pool_addr), 1, "pool nft balance");
    assertEq(puzzArt.tokenOfOwnerByIndex(pool_addr, 0), 10, "token of pool owner at index 0");
    // check pool funds
    assertEq(pool_addr.balance, 0, "pool funds");
    assertEq(pool.getFunds(), 0);

    // check fee receiver funds
    assertEq(puzzArt_addr.balance, q.fee, "received fee");
  }

  function test_Sell_SellAll() public {
    _buySomeNfts(11, 2048 gwei);

    SellQuote memory q = pool.getSellQuote(11);

    uint[] memory ids = _getTokenIdArray(11, 10);
    vm.prank(wallet1);
    pool.sell(ids);

    // check caller funds
    assertEq(wallet1.balance, q.outputValue, "caller funds");
    // check caller nfts
    assertEq(puzzArt.balanceOf(wallet1), 0, "caller nfts");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 0, "token of owner at index 0");

    // check pool NFTs
    assertEq(pool.getTotalNftsForSale(), 11, "pool nfts for sale");
    assertEq(puzzArt.balanceOf(pool_addr), 11, "pool nft balance");
    assertEq(puzzArt.tokenOfOwnerByIndex(pool_addr, 0), 10, "token of pool owner at index 0");
    assertEq(puzzArt.tokenOfOwnerByIndex(pool_addr, 1), 11, "token of pool owner at index 1");
    assertEq(puzzArt.tokenOfOwnerByIndex(pool_addr, 10), 20, "token of pool owner at index 10");
    // check pool funds
    assertEq(pool_addr.balance, 0, "pool funds");
    assertEq(pool.getFunds(), 0);
    
    // check fee receiver funds
    assertEq(puzzArt_addr.balance, q.fee, "received fee");
  }

  function test_Sell_InsufficientNfts() public {
    _buySomeNfts(2, 4 gwei);

    // get rid of all but 1
    vm.prank(wallet1);
    uint[] memory ids = _getTokenIdArray(1, 10);
    puzzArt.batchTransferIds(wallet1, wallet2, ids);

    // try to sell 2
    ids = _getTokenIdArray(2, 10);
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.InsufficientSenderNfts.selector, wallet1, 2, 1));
    pool.sell(ids);
  }

  function test_Sell_TooManyNfts() public {
    _buySomeNfts(2, 4 gwei);

    // try to sell 2
    uint[] memory ids = _getTokenIdArray(3, 10);
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INSUFFICIENT_FUNDS));
    pool.sell(ids);
  }

  function test_Sell_None() public {
    _buySomeNfts(2, 4 gwei);

    // try to sell 2
    uint[] memory ids = new uint[](0);
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(LibErrors.BadQuote.selector, wallet1, QuoteError.INVALID_NUMITEMS));
    pool.sell(ids);
  }

  function test_Sell_OutOfRangeIds_IsOk() public {
    // will buy with ids: 10, 11 - this will ensure pool has funds
    _buySomeNfts(2, 4 gwei);

    vm.startPrank(wallet1);

    // mint ids 20, 21
    _puzzArt_mint(wallet1, 20, "uri", 0);
    _puzzArt_mint(wallet1, 21, "uri", 0);

    SellQuote memory q = pool.getSellQuote(2);

    // try to sell with ids: 20, 21
    uint[] memory ids = _getTokenIdArray(2, 20);
    pool.sell(ids);

    vm.stopPrank();

    // check caller funds
    assertEq(wallet1.balance, q.outputValue, "caller funds");
    // check caller nfts
    assertEq(puzzArt.balanceOf(wallet1), 2, "caller nfts");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 10, "token of owner at index 0");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 1), 11, "token of owner at index 1");

    // check pool NFTs
    assertEq(pool.getTotalNftsForSale(), 11, "pool nfts for sale");
    assertEq(puzzArt.balanceOf(pool_addr), 2, "pool nft balance");
    assertEq(puzzArt.tokenOfOwnerByIndex(pool_addr, 0), 20, "token of pool owner at index 0");
    assertEq(puzzArt.tokenOfOwnerByIndex(pool_addr, 1), 21, "token of pool owner at index 1");
    // check pool funds
    assertEq(pool_addr.balance, 0, "pool funds");
    assertEq(pool.getFunds(), 0);
    
    // check fee receiver funds
    assertEq(puzzArt_addr.balance, q.fee, "received fee");
  }

  function test_Sell_SenderIsNotNftOwner() public {
    // will buy ids: 10, 11
    _buySomeNfts(2, 4 gwei);

    // send #10 to wallet2
    vm.prank(wallet1);
    puzzArt.safeTransferFrom(wallet1, wallet2, 10);

    // at this point, wallet1 has #11, wallet2 has #10

    uint[] memory ids = _getTokenIdArray(1, 10);
    vm.prank(wallet1);
    vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidOwner.selector, wallet1, 10));
    pool.sell(ids);
  }

  // mint-on-demand

  function test_MintOnDemand() public {
    _buySomeNfts(2, 4 gwei);

    uint[] memory ids = _getTokenIdArray(2, 10);
    _sellSomeNfts(ids, 1 gwei);

    // check NFTs minted
    assertEq(puzzArt.totalSupply(), 2, "nft supply");
    assertEq(puzzArt.tokenByIndex(0), 10, "token at index 0");
    assertEq(puzzArt.tokenByIndex(1), 11, "token at index 1");

    // check caller nfts
    assertEq(puzzArt.balanceOf(wallet1), 0);

    // check pool NFTs
    assertEq(puzzArt.balanceOf(pool_addr), 2);
    assertEq(pool.getTotalNftsForSale(), 11);
    assertEq(puzzArt.tokenOfOwnerByIndex(pool_addr, 0), 10, "token of pool owner at index 0");
    assertEq(puzzArt.tokenOfOwnerByIndex(pool_addr, 1), 11, "token of pool owner at index 0");

    // buy some more
    _buySomeNfts(4, 16 gwei);

    // check NFTs minted
    assertEq(puzzArt.totalSupply(), 4, "nft supply");
    assertEq(puzzArt.tokenByIndex(0), 10, "token at index 0");
    assertEq(puzzArt.tokenByIndex(1), 11, "token at index 1");
    assertEq(puzzArt.tokenByIndex(2), 12, "token at index 2");
    assertEq(puzzArt.tokenByIndex(3), 13, "token at index 3");

    // check caller nfts
    assertEq(puzzArt.balanceOf(wallet1), 4);
    // reverse order here because it's FIFO
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 0), 11, "token of owner at index 0");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 1), 10, "token of owner at index 1");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 2), 12, "token of owner at index 2");
    assertEq(puzzArt.tokenOfOwnerByIndex(wallet1, 3), 13, "token of owner at index 3");

    // check pool NFTs
    assertEq(puzzArt.balanceOf(pool_addr), 0);
    assertEq(pool.getTotalNftsForSale(), 7 /* 11 - 4 */);
  }

  // helper methods

  function _buySomeNfts(uint numItems, uint expectedNewSpotPrice) private {
    BuyQuote memory q = pool.getBuyQuote(numItems);

    wallet1.transfer(q.inputValue);

    vm.prank(wallet1);
    pool.buy{value: wallet1.balance}(numItems);

    (, PoolStatus memory s) = pool.getCurveStatus();
    assertEq(s.priceWei, expectedNewSpotPrice, "expected spot price");

    // nullify received fees (to make test assertions easier later on)
    vm.prank(puzzArt_addr);
    payable(address(0)).transfer(puzzArt_addr.balance);
  }

  function _sellSomeNfts(uint[] memory ids, uint expectedNewSpotPrice) private {
    vm.prank(wallet1);
    pool.sell(ids);

    (, PoolStatus memory s) = pool.getCurveStatus();
    assertEq(s.priceWei, expectedNewSpotPrice, "expected spot price");

    // nullify received fees (to make test assertions easier later on)
    vm.prank(puzzArt_addr);
    payable(address(0)).transfer(puzzArt_addr.balance);

    // nullify received funds (to make test assertions easier later on)
    vm.prank(wallet1);
    payable(address(0)).transfer(wallet1.balance);
  }

  function _getTokenIdArray(uint count, uint startId) private pure returns (uint[] memory) {
    uint[] memory ids = new uint[](count);
    for (uint i = 0; i < count; i++) {
      ids[i] = startId + i;
    }
    return ids;
  }
}

