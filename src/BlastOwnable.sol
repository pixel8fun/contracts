// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Interface for Blast yield contract.
 * 
 * https://docs.blast.io/building/guides/gas-fees
 */
interface IBlast {
  function configureClaimableGas() external;
  function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256);
}


contract BlastOwnable is Ownable {
  /**
   * @dev True if deployed on Blast chain.
   */
  bool public IS_BLAST;
  /**
   @dev Blast yield contract address.
   */
  address public constant YIELD_CONTRACT_ADDRESS = 0x4300000000000000000000000000000000000002;

  /**
   * @dev Check if deployed on Blast chain and Blast yield contract is available.
   */
  constructor (address _owner) Ownable(_owner) {
    uint32 size;
    assembly {
      size := extcodesize(YIELD_CONTRACT_ADDRESS)
    }
    IS_BLAST = (size > 0);
    if (IS_BLAST) {
      IBlast c = IBlast(YIELD_CONTRACT_ADDRESS);
      c.configureClaimableGas();
    }
  }

  function claimGasRefunds() external onlyOwner {
    if (IS_BLAST) {
      IBlast(YIELD_CONTRACT_ADDRESS).claimAllGas(address(this), owner());
    }
  }
}
