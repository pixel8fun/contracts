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

        // Prize pool final pot
        uint pot;

        // Game state
        bool gameOver;
        mapping(address => bool) prizeClaimed;
    }

    // Mapping of Pixel8 contract address to its game data
    mapping(address => GameData) private games;

    constructor(address _pool) Base(_pool, msg.sender) {}

    // Interface

    function supportsInterface(bytes4 interfaceId) public view override(ERC165) returns (bool) {
        return type(IGameStats).interfaceId == interfaceId || ERC165.supportsInterface(interfaceId);
    }

    function addRevealPoints(uint _points) external {
        GameData storage game = games[msg.sender];
        if (game.gameOver) {
            revert LibErrors.GameOver();
        }

        _addPlayerPoints(game, msg.sender, _points);
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

    function setGameOver(uint256 _prizePoolPot) external {
        GameData storage game = games[msg.sender];
        if (game.gameOver) {
            revert LibErrors.GameOver();
        }
        game.gameOver = true;
        game.pot = _prizePoolPot;
    }

    function getPrizesWinners(address _pixel8) external view returns (
        uint prizePoolPot,
        address biggestThief,
        uint biggestThiefPoints,
        address biggestTrader,
        uint biggestTraderVolume,
        address[3] memory highestScorers,
        uint[3] memory highestScores
    ) {
        GameData storage game = games[_pixel8];
        
        prizePoolPot = game.pot;
        biggestThief = game.highestNumForceSwaps;
        biggestThiefPoints = game.numForceSwaps[game.highestNumForceSwaps];
        biggestTrader = game.highestTradingVolume;
        biggestTraderVolume = game.tradingVolume[game.highestTradingVolume];
        highestScorers = game.highestPoints;
        
        for (uint i = 0; i < 3; i++) {
            highestScores[i] = game.points[game.highestPoints[i]];
        }
    }

    function calculatePrize(address _pixel8, address _wallet) public view returns (uint) {
        GameData storage game = games[_pixel8];
        if (!game.gameOver) {
            return 0;
        }
        
        uint prize = 0;

        if (game.highestNumForceSwaps == _wallet) {
            prize += game.pot * 100 / 1000; // 10%
        }
        
        if (game.highestTradingVolume == _wallet) {
            prize += game.pot * 100 / 1000; // 10%
        }

        for (uint i = 0; i < 3; i++) {
            if (game.highestPoints[i] == _wallet) {
                if (i == 0) {
                    prize += game.pot * 450 / 1000; // 45%
                } else if (i == 1) {
                    prize += game.pot * 250 / 1000; // 25%
                } else if (i == 2) {
                    prize += game.pot * 100 / 1000; // 10%
                }
            }
        }

        return prize;
    }

    function claimPrize(address _pixel8, address _wallet) external {
        GameData storage game = games[_pixel8];
        if (!game.gameOver) {
            revert LibErrors.GameNotOver();
        }

        if (game.prizeClaimed[_wallet]) {
            revert LibErrors.PrizeAlreadyClaimed(_wallet);
        }

        game.prizeClaimed[_wallet] = true;

        // Call Pixel8 to send the prize
        (bool success, ) = _pixel8.call(
            abi.encodeWithSignature("payoutPrize(address,uint256)", _wallet, calculatePrize(_pixel8, _wallet))
        );
        if (!success) {
            revert LibErrors.PrizePayoutFailed(_wallet);
        }
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