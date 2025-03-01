// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

/**
 * @dev Game stats contract.
 */
interface IGameStats {
  function addRevealPoints(uint _points) external;

  function recordForceSwap(address _wallet) external;

  function setGameOver(uint256 _prizePoolPot) external;

  function getPrizesWinners(address _pixel8) external view returns (
    uint prizePoolPot,
    address biggestThief,
    uint biggestThiefPoints,
    address biggestTrader,
    uint biggestTraderVolume,
    address[3] memory highestScorers,
    uint[3] memory highestScores
  );  

  function calculatePrize(address _pixel8, address _wallet) external view returns (uint);

  function claimPrize(address _pixel8, address _wallet) external;

  /**
   * @dev Log trading volume.
   *
   * This method is used by the pool to record a trade for a given wallet.
   *
   * @param _pixel8 The address of the pixel8 contract.
   * @param _wallet The address of the wallet.
   * @param _amount The amount of trading volume.
   * @param _buyOrSell Whether the trade is a buy or sell.
   * @param _numItems The number of items traded.
   */
  function recordTrade(address _pixel8, address _wallet, uint _amount, bool _buyOrSell, uint _numItems) external;
}
