// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { QuoteError } from "./Common.sol";

library LibErrors {
  /**
  * @dev Unauthorized access.
  */
  error Unauthorized(address caller);

  /**
   * @dev The token has already been revealed.
   */
  error AlreadyRevealed(uint256 tokenId);

  /**
   * @dev The caller supplied an expired signature.
   */
  error SignatureExpired(address caller);

  /**
   @dev The caller supplied an invalid signature.
   */
  error SignatureInvalid(address caller);

  /**
   * @dev The caller supplied an already used signature.
   */
  error SignatureAlreadyUsed(address caller);

  /**
  * @dev The sender provided insufficient funds.
  */
  error InsufficientSenderFunds(address sender, uint fundsRequired, uint fundsProvided);

  /**
  * @dev The sender has an insufficient NFT balance.
  */
  error InsufficientSenderNfts(address sender, uint balanceRequired, uint balanceAvailable);

  /**
   * @dev Invalid batch operation array lengths.
   */
  error InvalidBatchLengths(uint length1, uint length2);

  /**
   * @dev Invalid buy/sell quote.
   */
  error BadQuote(address sender, QuoteError quoteError);

  /**
  * @dev Invalid mint price.
  */
  error InvalidMintPrice(uint price);

  /**
  * @dev Invalid mint start id.
  */
  error InvalidMintStartId(uint id);

  /**
  * @dev Invalid mint end id.
  */
  error InvalidMintEndId(uint id);

  /**
   * @dev Pool trading is disabled.
   */
  error TradingDisabled();

  /**
   * @dev The lottery has already been drawn.
   */
  error LotteryAlreadyDrawn();

  /**
   * @dev The given ticket cannot claim winnings.
   */
  error LotteryCannotClaimWinnings(uint ticket);

  /**
   * @dev The lottery cannot be drawn yet.
   */
  error LotteryCannotBeDrawnYet();

  /**
   * @dev The lottery ticket NFT has already been set.
   */
  error LotteryNFTAlreadySet();

  /**
   * @dev The lottery ticket NFT is invalid.
   */
  error LotteryNFTInvalid();

  /**
  * @dev Lottery no. of winning tickets already set.
  */
  error LotteryNumWinningTicketsAlreadySet();

  /**
  * @dev Lottery no. of winning tickets not yet set.
  */
  error LotteryNumWinningTicketsNotSet();

  /**
   * @dev Invalid number for no. of winning tickets in lottery.
   */
  error LotteryInvalidNumWinningTickets();
}