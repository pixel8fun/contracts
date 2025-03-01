// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { LibErrors } from "./LibErrors.sol";
import { Base } from "./Base.sol";
import { IGameStats } from "./IGameStats.sol";
import { ERC165 } from "openzeppelin/utils/introspection/ERC165.sol";

contract GameStats is Base, IGameStats, ERC165   {
    event TradeRecorded(address pixel8, address wallet, uint amount, bool buyOrSell, uint numItems);

    struct GameData {
        // Points tracking
        mapping(address => uint) points;
        address[3] highestPoints;

        // Force swap stats
        mapping(address => uint) numForceSwaps;
        address highestNumForceSwaps;

        // Trading stats
        mapping(address => uint) tradingVolume;
        address highestTradingVolume;

        // Game state
        bool gameOver;
    }

    // Mapping of Pixel8 contract address to its game data
    mapping(address => GameData) public games;

    constructor(address _owner, address _pool) Base(_pool, _owner) {}

    // Getters for mappings

    function tradingVolume(address _pixel8, address _wallet) external view returns (uint) {
        return games[_pixel8].tradingVolume[_wallet];
    }

    function highestTradingVolume(address _pixel8) external view returns (address) {
        return games[_pixel8].highestTradingVolume;
    }

    function numForceSwaps(address _pixel8, address _wallet) external view returns (uint) {
        return games[_pixel8].numForceSwaps[_wallet];
    }

    function highestNumForceSwaps(address _pixel8) external view returns (address) {
        return games[_pixel8].highestNumForceSwaps;
    }

    function points(address _pixel8, address _wallet) external view returns (uint) {
        return games[_pixel8].points[_wallet];
    }

    function highestPoints(address _pixel8) external view returns (address[3] memory) {
        return games[_pixel8].highestPoints;
    }

    // Interface

    function supportsInterface(bytes4 interfaceId) public view override(ERC165) returns (bool) {
        return type(IGameStats).interfaceId == interfaceId || ERC165.supportsInterface(interfaceId);
    }

    function addRevealPoints(address _wallet, uint _points) external {
        GameData storage game = games[msg.sender];
        if (game.gameOver) {
            revert LibErrors.GameOver();
        }

        _addPlayerPoints(game, _wallet, _points);
    }

    function recordForceSwap(address _wallet) external {
        GameData storage game = games[msg.sender];
        if (game.gameOver) {
            revert LibErrors.GameOver();
        }

        game.numForceSwaps[_wallet]++;
        if (game.numForceSwaps[_wallet] > game.numForceSwaps[game.highestNumForceSwaps]) {
            game.highestNumForceSwaps = _wallet;
        }
    }

    function recordTrade(address _pixel8, address _wallet, uint _amount, bool _buyOrSell, uint _numItems) external onlyPool {
        GameData storage game = games[_pixel8];
        if (!game.gameOver) {
            game.tradingVolume[_wallet] += _amount;

            if (game.tradingVolume[_wallet] > game.tradingVolume[game.highestTradingVolume]) {
                game.highestTradingVolume = _wallet;
            }

            emit TradeRecorded(_pixel8, _wallet, _amount, _buyOrSell, _numItems);
        }
    }

    function setGameOver() external {
        GameData storage game = games[msg.sender];
        if (game.gameOver) {
            revert LibErrors.GameOver();
        }
        game.gameOver = true;
    }

    function getPrizesWinners(address _pixel8) external view returns (PrizesWinners memory winners) {
        GameData storage game = games[_pixel8];
        
        winners.biggestThief = game.highestNumForceSwaps;
        winners.biggestThiefPoints = game.numForceSwaps[game.highestNumForceSwaps];
        winners.biggestTrader = game.highestTradingVolume;
        winners.biggestTraderVolume = game.tradingVolume[game.highestTradingVolume];
        winners.highestScorers = game.highestPoints;
        
        for (uint i = 0; i < 3; i++) {
            winners.highestScores[i] = game.points[game.highestPoints[i]];
        }
    }

    function calculatePrize(address _pixel8, uint _prizePoolPot,address _wallet) public view returns (uint) {
        GameData storage game = games[_pixel8];
        if (!game.gameOver) {
            return 0;
        }

        uint prize = 0;

        if (game.highestNumForceSwaps == _wallet) {
            prize += _prizePoolPot * 100 / 1000; // 10%
        }
        
        if (game.highestTradingVolume == _wallet) {
            prize += _prizePoolPot * 100 / 1000; // 10%
        }

        for (uint i = 0; i < 3; i++) {
            if (game.highestPoints[i] == _wallet) {
                if (i == 0) {
                    prize += _prizePoolPot * 450 / 1000; // 45%
                } else if (i == 1) {
                    prize += _prizePoolPot * 250 / 1000; // 25%
                } else if (i == 2) {
                    prize += _prizePoolPot * 100 / 1000; // 10%
                }
            }
        }

        return prize;
    }

    // Internal/private methods

    function _addPlayerPoints(GameData storage game, address _wallet, uint _points) private {
        game.points[_wallet] += _points;

        // update highest points list

        // first go through list and see if wallet is already a high scorer
        uint i = 0;
        while (i < 3) {
            if (game.highestPoints[i] == _wallet) {
                break;
            }
            i++;
        }

        // if not in list but it should be, then add it
        if (i == 3 && game.points[game.highestPoints[2]] < game.points[_wallet]) {
            game.highestPoints[2] = _wallet;
            i = 2;
        }

        // now check if it should be in the second position
        if (i == 2 && game.points[game.highestPoints[1]] < game.points[_wallet]) {
            address temp = game.highestPoints[1];
            game.highestPoints[1] = game.highestPoints[2];
            game.highestPoints[2] = temp;
            i = 1;
        } 
        
        // now check if it should be in the first position
        if (i == 1 && game.points[game.highestPoints[0]] < game.points[_wallet]) {
            address temp = game.highestPoints[0];
            game.highestPoints[0] = game.highestPoints[1];
            game.highestPoints[1] = temp;
        }
    }
} 