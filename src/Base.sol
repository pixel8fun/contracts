// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { LibErrors } from "./LibErrors.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";

abstract contract Base is Ownable {
  // Events
  event PoolSet(address newPool);

  address public pool;

  constructor(address _pool, address _owner) Ownable(_owner) {
    pool = _pool;
  }

  /**
   * @dev Set the pool address.
   */
  function setPool(address newPool) external onlyOwner {
    if (newPool == address(0)) {
      revert LibErrors.InvalidAddress(newPool);
    }
    if (pool != address(0)) {
      revert LibErrors.PoolAlreadySet();
    }
    pool = newPool;
    emit PoolSet(newPool);
  }

  modifier onlyPool() {
    if (msg.sender != pool) {
      revert LibErrors.Unauthorized(msg.sender);
    }
    _;
  }
} 