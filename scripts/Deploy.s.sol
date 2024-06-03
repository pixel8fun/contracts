// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { console as c } from "forge-std/Script.sol";
import { ScriptBase } from "./ScriptBase.sol";
import { PuzzArt } from "src/PuzzArt.sol";
import { LotteryNFT } from "src/LotteryNFT.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";

contract Deploy is ScriptBase {
  function run() public {
    Config memory cfg = _getScriptConfig();

    address wallet = cfg.owner;
    c.log("Owner:", wallet);

    vm.startBroadcast(wallet);

    c.log("Deploying PuzzArt...");

    PuzzArt.Config memory puzzArtConfig = _getPuzzArtConfig(cfg);
    c.log("PuzzArt constructor args:");
    c.logBytes(abi.encode(puzzArtConfig));

    PuzzArt puzzArt;
    address payable puzzArtAddress = _getDeployedAddress(type(PuzzArt).creationCode, abi.encode(puzzArtConfig));
    if (puzzArtAddress.code.length > 0) {
      c.log("PuzzArt already deployed at:", puzzArtAddress);
      puzzArt = PuzzArt(puzzArtAddress);
    } else {
      puzzArt = new PuzzArt{salt: CREATE2_SALT}(puzzArtConfig);
      c.log("PuzzArt:", address(puzzArt));
    }
    
    c.log("Deploying LotteryNFT...");

    LotteryNFT.Config memory lotteryNftConfig = _getLotteryNftConfig(cfg, puzzArtAddress);
    c.log("LotteryNFT constructor args:");
    c.logBytes(abi.encode(lotteryNftConfig));

    LotteryNFT lotteryNft;
    address lotteryNftAddress = _getDeployedAddress(type(LotteryNFT).creationCode, abi.encode(lotteryNftConfig));
    if (lotteryNftAddress.code.length > 0) {
      c.log("LotteryNFT already deployed at:", lotteryNftAddress);
      lotteryNft = LotteryNFT(lotteryNftAddress);
    } else {
      lotteryNft = new LotteryNFT{salt: CREATE2_SALT}(lotteryNftConfig);
      c.log("LotteryNFT:", address(lotteryNft));
    }

    c.log("Deploying MintSwapPool...");

    MintSwapPool.Config memory poolConfig = _getMintSwapPoolConfig(cfg, puzzArtAddress);
    c.log("MintSwapPool constructor args:");
    c.logBytes(abi.encode(poolConfig));

    MintSwapPool pool;
    address poolAddress = _getDeployedAddress(type(MintSwapPool).creationCode, abi.encode(poolConfig));
    if (poolAddress.code.length > 0) {
      c.log("MintSwapPool already deployed at:", poolAddress);
      pool = MintSwapPool(poolAddress);
    } else {
      pool = new MintSwapPool{salt: CREATE2_SALT}(poolConfig);
      c.log("MintSwapPool:", poolAddress);
    }

    address currentPool = puzzArt.pool();
    if (currentPool != poolAddress) {
      c.log("Enable pool on PuzzArt contract...");
      puzzArt.setPool(poolAddress);
    } else {
      c.log("Pool already enabled on PuzzArt contract...");    
    }

    address currentLottery = address(puzzArt.getLottery().nft);
    if (currentLottery != lotteryNftAddress) {
      c.log("Enable lottery on PuzzArt contract...");
      puzzArt.setLotteryNFT(lotteryNftAddress);
    } else {
      c.log("Lottery already enabled on PuzzArt contract...");    
    }

    c.log("All done");

    vm.stopBroadcast();        
  }
}
