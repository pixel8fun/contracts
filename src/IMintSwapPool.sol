// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { PoolCurve } from "./Common.sol";


/**
 * @dev MintSwapPool.
 */
interface IMintSwapPool {
  /**
   * @dev Configuration parameters for a pool.
   */
  struct PoolConfig {
    /** Pixel8 contract */
    address nft;
    /** Price curves (and thus liquidity pools) */
    PoolCurve curve;
  }

  /**
   * @dev Create a new pool for an NFT contract.
   * @param config Pool configuration.
   */
  function create(PoolConfig memory config) external;
}
