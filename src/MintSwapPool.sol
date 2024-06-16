// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { IPixel8 } from "./IPixel8.sol";
import { LibErrors } from "./LibErrors.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { PoolCurve, PoolStatus, QuoteError, BuyQuote, SellQuote } from "./Common.sol";
import { ExponentialCurve } from "./ExponentialCurve.sol";
import { IERC721TokenReceiver } from "./ERC721.sol";

/**
 * @dev NFT liquidity pool that both mints and swaps.
 *
 * Inspired by SudoSwap, this provides a way for users to mint, buy and sell NFTs easily from/to a self-managed 
 * liquidity pool. 
 *
 * Initially no NFTs are minted. The first purchase mints an NFT. The price of an NFT increases with each mint. A minted 
 * NFT can be sold back into the pool at the current mint price to get back liquidity. The price of an NFT decreases with 
 * every sale back to the pool. Subsequent buyers will then first recieve existing NFTs already held by the pool before a new 
 * ones are minted.
 *
 * Note that subsequent buyers receive the most recently added NFTs first, i.e. FIFO order. For example, if seller A sells NFT #1 and then #2
 * to the pool, then the next buyer will first receive NFT #2, followed by NFT #1. Buyers can, however, buy specific NFTs by id from the pool if 
 * those ids are already minted.
 *
 * Mint price follows an exponential bonding curve, meaning price increases by a fixed percentage with each purchase.
 */
contract MintSwapPool is Ownable, IERC721TokenReceiver, ExponentialCurve {
  IPixel8 public nft;
  PoolCurve public curve;
  PoolStatus public status;

  /**
   * @dev Wheter trading is enabled or not.
   */
  bool public enabled = true;

  // Constructor

  /**
   * @dev Configuration parameters.
   */
  struct Config {
    /** Owner of pool */
    address owner;
    /** Pixel8 contractx. */
    address nft;
    /** Price curves (and thus liquidity pools) */
    PoolCurve curve;
  }

  constructor(Config memory _config) Ownable(_config.owner) {
    if (!validateSpotPrice(_config.curve.startPriceWei)) {
      revert LibErrors.InvalidMintPrice(_config.curve.startPriceWei);
    }

    if (_config.curve.mintStartId < 1) {
      revert LibErrors.InvalidMintStartId(_config.curve.mintStartId);
    }

    if (_config.curve.mintEndId < _config.curve.mintStartId) {
      revert LibErrors.InvalidMintEndId(_config.curve.mintEndId);
    }

    nft = IPixel8(_config.nft);
    
    curve = _config.curve;
    
    status = PoolStatus({
      lastMintId: _config.curve.mintStartId - 1,
      priceWei: curve.startPriceWei
    });
  }

  // ---------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------

  /**
   * @dev Set whether trading is enabled.
   */
  function setEnabled(bool _enabled) external onlyOwner {
    enabled = _enabled;
  }

  /**
   * @dev Get the curve config and status.
   */
  function getCurveStatus() public view returns (PoolCurve memory, PoolStatus memory) {
    return (curve, status);
  }


  // ---------------------------------------------------------------
  // Buying
  // ---------------------------------------------------------------

  /**
    * @dev Buy a specific NFT from the pool.
    * @param _id Id of the NFT to buy.
    */
  function buySpecific(uint _id) external payable returns (BuyQuote memory quote) {
    address sender = payable(msg.sender);

    quote = _preBuy(1);

    nft.safeTransferFrom(address(this), sender, _id, "");

    _postBuy(sender, quote);
  }

  /**
   * @dev Buy NFTs from the pool.
   * @param numItems Number of NFTs to buy.
   */
  function buy(uint numItems) external payable returns (BuyQuote memory quote) {
    address sender = payable(msg.sender);

    quote = _preBuy(numItems);

    // transfer from balance first
    uint balance = nft.balanceOf(address(this));
    if (balance > 0) {
      uint toTransfer = balance < numItems ? balance : numItems;
      nft.batchTransferRange(address(this), sender, toTransfer);
      numItems -= toTransfer;
    }

    // mint remaining
    if (numItems > 0) {
      nft.batchMint(sender, status.lastMintId + 1, numItems);
      status.lastMintId += numItems;
    }

    _postBuy(sender, quote);
  }

  /**
   * @dev Pre-buy processing.
   * @param numItems Number of NFTs to buy.
   */
  function _preBuy(uint numItems) private returns (BuyQuote memory quote) {
    if (!enabled) {
      revert LibErrors.TradingDisabled();
    }

    address sender = payable(msg.sender);

    quote = getBuyQuote(numItems);

    if (quote.error != QuoteError.NONE) {
      revert LibErrors.BadQuote(sender, quote.error);
    }

    // check sender funds
    if (quote.inputValue > msg.value) {
      revert LibErrors.InsufficientSenderFunds(sender, quote.inputValue, msg.value);
    }

    // update status
    status.priceWei = quote.newSpotPrice;
  }

  /**
   * @dev Post-buy processing.
   * @param sender Buyer.
   * @param quote Buy quote.
   */
  function _postBuy(address sender, BuyQuote memory quote) private {
    // pay fee
    payable(quote.feeReceiver).transfer(quote.fee);

    // return excess payment to caller
    if (quote.inputValue < msg.value) {
      payable(sender).transfer(msg.value - quote.inputValue);
    }
  }

  /**
   * @dev Get total available NFTs for sale.
   */
  function getTotalNftsForSale() public view returns (uint) {
    return nft.balanceOf(address(this)) + (curve.mintEndId - status.lastMintId);
  }

  /**
   * @dev Get total funds in the pool.
   */
  function getFunds() public view returns (uint) {
    return address(this).balance;
  }

  /**
   * @dev Get the buy quote for a given number of items.
   * @param numItems Number of NFTs to buy.
   */
  function getBuyQuote(uint numItems) public view returns (BuyQuote memory quote) {
    (address feeReceiver, uint feeBips) = nft.getRoyaltyInfo();
    
    quote = getBuyInfo(status.priceWei, curve.delta, numItems, feeBips);
    quote.feeReceiver = feeReceiver;

    if (quote.error == QuoteError.NONE) {
      // check NFTs available
      uint nftsAvailable = getTotalNftsForSale(); 
      if (numItems > nftsAvailable) {
        quote.error = QuoteError.INSUFFICIENT_NFTS;
      }
    }
  }

  // ---------------------------------------------------------------
  // Selling
  // ---------------------------------------------------------------


  function sell(uint[] calldata tokenIds) external returns (SellQuote memory quote) {
    if (!enabled) {
      revert LibErrors.TradingDisabled();
    }

    address sender = payable(msg.sender);

    quote = getSellQuote(tokenIds.length);

    if (quote.error != QuoteError.NONE) {
      revert LibErrors.BadQuote(sender, quote.error);
    }

    // check balance
    uint tokenBal = nft.balanceOf(sender);
    if (tokenIds.length > tokenBal) {
      revert LibErrors.InsufficientSenderNfts(sender, tokenIds.length, tokenBal);
    }
    
    // update status
    status.priceWei = quote.newSpotPrice;

    // transfer NFTs to pool
    nft.batchTransferIds(sender, address(this), tokenIds);

    // pay caller
    payable(sender).transfer(quote.outputValue);

    // pay fee
    payable(quote.feeReceiver).transfer(quote.fee);
  }

  /**
   * @dev Get the sell quote for a given number of items.
   * @param numItems Number of NFTs to sell.
   */
  function getSellQuote(uint numItems) public view returns (SellQuote memory quote) {
    (address feeReceiver, uint feeBips) = nft.getRoyaltyInfo();

    quote = getSellInfo(status.priceWei, curve.delta, numItems, feeBips);
    quote.feeReceiver = feeReceiver;

    if (quote.error == QuoteError.NONE) {
      // check that pool has enough balance to pay
      uint totalToPay = quote.outputValue + quote.fee;
      if (totalToPay > address(this).balance) {
        quote.error = QuoteError.INSUFFICIENT_FUNDS;
      }
    }
  }

  // ---------------------------------------------------------------
  // IERC721TokenReceiver
  // ---------------------------------------------------------------

  function onERC721Received(
    address /*operator*/,
    address /*from*/,
    uint256 /*tokenId*/,
    bytes calldata /*data*/
  ) public pure override returns (bytes4) {
    return IERC721TokenReceiver.onERC721Received.selector;
  }
}
