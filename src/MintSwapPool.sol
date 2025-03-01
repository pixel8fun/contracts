// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { IPixel8 } from "./IPixel8.sol";
import { IMintSwapPool } from "./IMintSwapPool.sol";
import { LibErrors } from "./LibErrors.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { PoolCurve, PoolStatus, QuoteError, BuyQuote, SellQuote } from "./Common.sol";
import { ExponentialCurve } from "./ExponentialCurve.sol";
import { IERC721TokenReceiver } from "./ERC721.sol";
import { ERC165 } from "openzeppelin/utils/introspection/ERC165.sol";
import { IGameStats } from "./IGameStats.sol";

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
contract MintSwapPool is Ownable, IERC721TokenReceiver, ExponentialCurve, IMintSwapPool, ERC165 {
  /**
   * @dev Pool status.
   */
  struct Pool {
    IPixel8 nft;
    IGameStats stats;
    PoolCurve curve;
    PoolStatus status;
    uint funds;
  }

  // Mapping from NFT contract address to pool ID
  uint public poolCount;
  mapping(address => uint) public poolIds;
  mapping(uint => Pool) public pools;

  address public poolCreator;

  constructor(address _owner, address _poolCreator) Ownable(_owner) {
    poolCreator = _poolCreator;
  }

  // Interface

  function supportsInterface(bytes4 interfaceId) public view override(ERC165) returns (bool) {
    return type(IMintSwapPool).interfaceId == interfaceId
      || ERC165.supportsInterface(interfaceId);
  }

  /**
   * @dev Set the pool creator.
   */
  function setPoolCreator(address _poolCreator) public onlyOwner {
    poolCreator = _poolCreator;
  }

  /**
   * @dev Get the pool for a given NFT contract.
   * @param nftAddress Address of the NFT contract.
   */
  function _getPool(address nftAddress) internal view returns (Pool storage) {
    uint poolId = poolIds[nftAddress];
    if (poolId == 0) {
        revert LibErrors.PoolDoesNotExist(nftAddress);
    }
    return pools[poolId];
  }

  /**
   * @dev Create a new pool for an NFT contract.
   * @param config Pool configuration.
   */
  function create(PoolConfig memory config) external onlyPoolCreator {
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

    IPixel8 pixel8 = IPixel8(config.nft);

    Pool memory pool = Pool({
      nft: pixel8,
      stats: pixel8.gameStats(),
      curve: config.curve,
      status: PoolStatus({
        lastMintId: config.curve.mintStartId - 1,
        priceWei: config.curve.startPriceWei
      }),
      funds: 0
    });

    poolCount++;
    pools[poolCount] = pool;
    poolIds[config.nft] = poolCount;
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
    
    address sender = _msgSender();

    quote = _preBuy(pool, 1);

    pool.nft.safeTransferFrom(address(this), sender, _id, "");

    _postBuy(pool, sender, quote, 1);
  }

  /**
   * @dev Buy NFTs from the pool.
   * @param nftAddress Address of the NFT contract.
   * @param numItems Number of NFTs to buy.
   */
  function buy(address nftAddress, uint numItems) external payable returns (BuyQuote memory quote) {
    Pool storage pool = _getPool(nftAddress);

    address sender = _msgSender();

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

    _postBuy(pool, sender, quote, numItems);
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
    address sender = _msgSender();

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
   * @param numItems Number of NFTs bought.
   */
  function _postBuy(Pool storage pool, address sender, BuyQuote memory quote, uint numItems) internal {
    // add funds to pool
    pool.funds += (quote.inputValue - quote.fee);
    pool.status.priceWei = quote.newSpotPrice;

    // pay fee
    payable(quote.feeReceiver).transfer(quote.fee);

    // return excess payment to caller
    if (quote.inputValue < msg.value) {
      payable(sender).transfer(msg.value - quote.inputValue);
    }

    // record trade volume
    pool.stats.recordTrade(address(pool.nft), sender, quote.inputValue, true, numItems);
  }

  // ---------------------------------------------------------------
  // Selling
  // ---------------------------------------------------------------


  function sell(address nftAddress, uint[] calldata tokenIds) external returns (SellQuote memory quote) {
    Pool storage pool = _getPool(nftAddress);

    address sender = _msgSender();

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

    // record trade volume
    pool.stats.recordTrade(address(pool.nft), sender, quote.outputValue, false, tokenIds.length);
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


  // Modifiers

  /**
   * @dev Only the pool creator can call this function.
   */
  modifier onlyPoolCreator() {
    if (_msgSender() != poolCreator) {
      revert LibErrors.Unauthorized(_msgSender());
    }
    _;
  }

}
