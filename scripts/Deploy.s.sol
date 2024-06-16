// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { console as c } from "forge-std/Script.sol";
import { ScriptBase } from "./ScriptBase.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";

contract Deploy is ScriptBase {
  function run() public {
    Config memory cfg = _getScriptConfig();

    address wallet = cfg.owner;
    c.log("Owner:", wallet);

    vm.startBroadcast(wallet);

    c.log("Deploying Pixel8...");

    Pixel8.Config memory pixel8Config = _getPixel8Config(cfg);
    c.log("Pixel8 constructor args:");
    c.logBytes(abi.encode(pixel8Config));

    Pixel8 pixel8;
    address payable pixel8Address = _getDeployedAddress(type(Pixel8).creationCode, abi.encode(pixel8Config));
    if (pixel8Address.code.length > 0) {
      c.log("Pixel8 already deployed at:", pixel8Address);
      pixel8 = Pixel8(pixel8Address);
    } else {
      pixel8 = new Pixel8{salt: CREATE2_SALT}(pixel8Config);
      c.log("Pixel8:", address(pixel8));
    }

    c.log("Deploying MintSwapPool...");

    MintSwapPool.Config memory poolConfig = _getMintSwapPoolConfig(cfg, pixel8Address);
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

    address currentPool = pixel8.pool();
    if (currentPool != poolAddress) {
      c.log("Enable pool on Pixel8 contract...");
      pixel8.setPool(poolAddress);
    } else {
      c.log("Pool already enabled on Pixel8 contract...");    
    }

    c.log("All done");

    vm.stopBroadcast();        
  }
}
