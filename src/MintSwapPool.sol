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
  /**
   * @dev Pool status.
   */
  struct Pool {
    IPixel8 nft;
    PoolCurve curve;
    PoolStatus status;
    uint funds;
  }

  /**
   * @dev Configuration parameters for a pool.
   */
  struct PoolConfig {
    /** Pixel8 contract */
    address nft;
    /** Price curves (and thus liquidity pools) */
    PoolCurve curve;
  }

  // Mapping from NFT contract address to pool ID
  mapping(address => uint) public poolIds;

  // Array of all pools
  Pool[] public pools;

  constructor(address owner) Ownable(owner) {}

  /**
   * @dev Get the pool for a given NFT contract.
   * @param nftAddress Address of the NFT contract.
   */
  function _getPool(address nftAddress) internal view returns (Pool storage) {
    uint poolId = poolIds[nftAddress];
    if (poolId == 0) {
        revert LibErrors.PoolDoesNotExist(nftAddress);
    }
    return pools[poolId - 1];
  }

  /**
   * @dev Create a new pool for an NFT contract.
   * @param config Pool configuration.
   */
  function create(PoolConfig memory config) external onlyOwner {
    if (!validateSpotPrice(config.curve.startPriceWei)) {
      revert LibErrors.InvalidMintPrice(config.curve.startPriceWei);
    }

    if (config.curve.mintStartId < 1) {
      revert LibErrors.InvalidMintStartId(config.curve.mintStartId);
    }

    if (config.curve.mintEndId < config.curve.mintStartId) {
      revert LibErrors.InvalidMintEndId(config.curve.mintEndId);
    }

    if (poolIds[config.nft] != 0) {
      revert LibErrors.PoolAlreadyExists(config.nft);
    }

    Pool memory pool = Pool({
      nft: IPixel8(config.nft),
      curve: config.curve,
      status: PoolStatus({
        lastMintId: config.curve.mintStartId - 1,
        priceWei: config.curve.startPriceWei
      }),
      funds: 0
    });

    pools.push(pool);
    poolIds[config.nft] = pools.length;
  }

  // ---------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------

  /**
   * @dev Get the curve config and status.
   * @param nftAddress Address of the NFT contract.
   */
  function getCurveStatus(address nftAddress) external view returns (PoolCurve memory, PoolStatus memory) {
    Pool storage pool = _getPool(nftAddress);
    return (pool.curve, pool.status);
  }


  // ---------------------------------------------------------------
  // Buying
  // ---------------------------------------------------------------

  /**
    * @dev Buy a specific NFT from the pool.
    * @param nftAddress Address of the NFT contract.
    * @param _id Id of the NFT to buy.
    */
  function buySpecific(address nftAddress, uint _id) external payable returns (BuyQuote memory quote) {
    Pool storage pool = _getPool(nftAddress);
    
    address sender = msg.sender;

    quote = _preBuy(pool, 1);

    pool.nft.safeTransferFrom(address(this), sender, _id, "");

    _postBuy(pool, sender, quote);
  }

  /**
   * @dev Buy NFTs from the pool.
   * @param nftAddress Address of the NFT contract.
   * @param numItems Number of NFTs to buy.
   */
  function buy(address nftAddress, uint numItems) external payable returns (BuyQuote memory quote) {
    Pool storage pool = _getPool(nftAddress);

    address sender = msg.sender;

    quote = _preBuy(pool, numItems);

    uint balance = pool.nft.balanceOf(address(this));
    if (balance > 0) {
      uint toTransfer = balance < numItems ? balance : numItems;
      pool.nft.batchTransferRange(address(this), sender, toTransfer);
      numItems -= toTransfer;
    }

    if (numItems > 0) {
      pool.nft.batchMint(sender, pool.status.lastMintId + 1, numItems);
      pool.status.lastMintId += numItems;
    }

    _postBuy(pool, sender, quote);
  }


  /**
   * @dev Get total available NFTs for sale.
   * @param nftAddress Address of the NFT contract.
   */
  function getTotalNftsForSale(address nftAddress) external view returns (uint) {
    Pool storage pool = _getPool(nftAddress);
    return pool.nft.balanceOf(address(this)) + (pool.curve.mintEndId - pool.status.lastMintId);
  }


  /**
   * @dev Get the buy quote for a given number of items.
   * @param nftAddress Address of the NFT contract.
   * @param numItems Number of NFTs to buy.
   */
  function getBuyQuote(address nftAddress, uint numItems) external view returns (BuyQuote memory) {
    Pool storage pool = _getPool(nftAddress);
    return _getBuyQuote(pool, numItems);
  }


  /**
   * @dev Get the buy quote for a given number of items.
   * @param numItems Number of NFTs to buy.
   */
  function _getBuyQuote(Pool storage pool, uint numItems) internal view returns (BuyQuote memory quote) {
    (address feeReceiver, uint feeBips) = pool.nft.getRoyaltyInfo();
    
    quote = getBuyInfo(pool.status.priceWei, pool.curve.delta, numItems, feeBips);
    quote.feeReceiver = feeReceiver;

    if (quote.error == QuoteError.NONE) {
      uint nftsAvailable = pool.nft.balanceOf(address(this)) + (pool.curve.mintEndId - pool.status.lastMintId);
      if (numItems > nftsAvailable) {
        quote.error = QuoteError.INSUFFICIENT_NFTS;
      }
    }
  }

  /**
   * @dev Pre-buy processing.
   * @param pool Pool.
   * @param numItems Number of NFTs to buy.
   */
  function _preBuy(Pool storage pool, uint numItems) internal returns (BuyQuote memory quote) {
    address sender = msg.sender;

    quote = _getBuyQuote(pool, numItems);

    if (quote.error != QuoteError.NONE) {
      revert LibErrors.BadQuote(sender, quote.error);
    }

    if (quote.inputValue > msg.value) {
      revert LibErrors.InsufficientSenderFunds(sender, quote.inputValue, msg.value);
    }
  }


  /**
   * @dev Post-buy processing.
   * @param sender Buyer.
   * @param quote Buy quote.
   */
  function _postBuy(Pool storage pool, address sender, BuyQuote memory quote) internal {
    // add funds to pool
    pool.funds += (quote.inputValue - quote.fee);
    pool.status.priceWei = quote.newSpotPrice;

    // pay fee
    payable(quote.feeReceiver).transfer(quote.fee);

    // return excess payment to caller
    if (quote.inputValue < msg.value) {
      payable(sender).transfer(msg.value - quote.inputValue);
    }
  }

  // ---------------------------------------------------------------
  // Selling
  // ---------------------------------------------------------------


  function sell(address nftAddress, uint[] calldata tokenIds) external returns (SellQuote memory quote) {
    Pool storage pool = _getPool(nftAddress);

    address sender = msg.sender;

    quote = _getSellQuote(pool, tokenIds.length);

    if (quote.error != QuoteError.NONE) {
      revert LibErrors.BadQuote(sender, quote.error);
    }

    uint tokenBal = pool.nft.balanceOf(sender);
    if (tokenIds.length > tokenBal) {
      revert LibErrors.InsufficientSenderNfts(sender, tokenIds.length, tokenBal);
    }
    
    pool.status.priceWei = quote.newSpotPrice;
    pool.funds -= (quote.outputValue + quote.fee);

    pool.nft.batchTransferIds(sender, address(this), tokenIds);
    payable(sender).transfer(quote.outputValue);
    payable(quote.feeReceiver).transfer(quote.fee);
  }

  /**
   * @dev Get the sell quote for a given number of items.
   * @param nftAddress Address of the NFT contract.
   * @param numItems Number of NFTs to sell.
   */
  function getSellQuote(address nftAddress, uint numItems) external view returns (SellQuote memory) {
    Pool storage pool = _getPool(nftAddress);
    return _getSellQuote(pool, numItems);
  }


  /**
   * @dev Get the sell quote for a given number of items.
   * @param numItems Number of NFTs to sell.
   */
  function _getSellQuote(Pool storage pool, uint numItems) internal view returns (SellQuote memory quote) {
    (address feeReceiver, uint feeBips) = pool.nft.getRoyaltyInfo();

    quote = getSellInfo(pool.status.priceWei, pool.curve.delta, numItems, feeBips);
    quote.feeReceiver = feeReceiver;

    if (quote.error == QuoteError.NONE) {
      uint totalToPay = quote.outputValue + quote.fee;

      if (totalToPay > pool.funds || totalToPay > address(this).balance) {
        quote.error = QuoteError.INSUFFICIENT_FUNDS;
      }
    }
  }


  // ---------------------------------------------------------------
  // Funds
  // ---------------------------------------------------------------

  /**
   * @dev Get total funds in the pool.
   * @param nftAddress Address of the NFT contract.
   */
  function getFunds(address nftAddress) external view returns (uint) {
    Pool storage pool = _getPool(nftAddress);
    return pool.funds;
  }  

  // ---------------------------------------------------------------
  // IERC721TokenReceiver
  // ---------------------------------------------------------------

  function onERC721Received(
    address /*operator*/,
    address /*from*/,
    uint256 /*tokenId*/,
    bytes calldata /*data*/
  ) external pure override returns (bytes4) {
    return IERC721TokenReceiver.onERC721Received.selector;
  }
}
