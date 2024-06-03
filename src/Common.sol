// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

enum QuoteError {
  // no error
  NONE,
  // invalid no. of items being bought/sold
  INVALID_NUMITEMS,
  // new spot price would overflow
  SPOT_PRICE_OVERFLOW,
  // not enough NFTs available in pool
  INSUFFICIENT_NFTS,
  // not enough funds in pool
  INSUFFICIENT_FUNDS
}

struct BuyQuote {
  QuoteError error;
  uint128 newSpotPrice;
  uint256 inputValue;
  uint256 fee;
  address feeReceiver;
}

struct SellQuote {
  QuoteError error;
  uint128 newSpotPrice;
  uint256 outputValue;
  uint256 fee;
  address feeReceiver;
}

struct PoolStatus {
  /** Id of last token minted. */
  uint256 lastMintId;
  /** Current price (in wei). */
  uint128 priceWei;
}

struct PoolCurve {
  /** Token id to mint from. */
  uint256 mintStartId;
  /** Token id to mint to. */
  uint256 mintEndId;
  /** Price at beginning (in wei). */
  uint128 startPriceWei;
  /** 
  Multipler/divisor to apply after each purchase/sale. 
  
  Raw value should be multiplied by 1^18 to get the stored value. For example:
  - 1.1 = 1.1 * 1^18 = 1100000000000000000
  - 1.0001 = 1.0001 * 1^18 = 1000100000000000000
  */
  uint128 delta;
}

