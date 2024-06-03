// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { IERC721Enumerable } from "openzeppelin/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @dev Lottery NFT.
 */
interface ILotteryNFT is IERC721Enumerable {
  /**
   * @dev Batch-mint tokens.
   *
   * @param _to The address which will own the minted tokens.
   * @param _count No. of tokens to mint.
   */
  function batchMint(address _to, uint _count) external;
}
