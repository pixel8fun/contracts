// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Script, console2 as c } from "forge-std/Script.sol";
import { Vm } from "forge-std/Vm.sol";
import { Strings } from "openzeppelin/utils/Strings.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { PoolCurve } from "src/Common.sol";

contract ScriptBase is Script {
  bytes32 internal constant ENV_MAINNET = keccak256(abi.encodePacked("mainnet"));
  bytes32 internal constant ENV_TESTNET = keccak256(abi.encodePacked("testnet"));

  bytes32 internal constant CREATE2_SALT = keccak256("Pixel8.deployment.salt4");
  string internal constant DEFAULT_PIXEL8_IMG = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9Im5vbmUiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIj48cGF0aCBmaWxsPSIjRDhEOEQ4IiBmaWxsLW9wYWNpdHk9Ii41IiBkPSJNMCAwaDUxMnY1MTJIMHoiLz48ZyBjbGlwLXBhdGg9InVybCgjYSkiPjxwYXRoIGZpbGw9IiMzMTMwMzAiIGQ9Ik0xOTcuNiAzNTJoMTE1LjhjNC44IDAgOC43LTMuOSA4LjctOC43VjI0NWMwLTQuOC00LTguNy04LjctOC43aC04Ljd2LTI2YTQ5LjMgNDkuMyAwIDAgMC05OC40IDB2MjZoLTguN2E4LjcgOC43IDAgMCAwLTguNyA4Ljd2OTguNGMwIDQuOCA0IDguNyA4LjcgOC43Wm02Ni42LTU1djExLjZhOC43IDguNyAwIDEgMS0xNy40IDBWMjk3YTE0LjUgMTQuNSAwIDEgMSAxNy40IDBabS00MC41LTg2LjhhMzEuOSAzMS45IDAgMCAxIDYzLjYgMHYyNmgtNjMuNnYtMjZaIi8+PC9nPjxkZWZzPjxjbGlwUGF0aCBpZD0iYSI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTE2MCAxNjFoMTkxdjE5MUgxNjB6Ii8+PC9jbGlwUGF0aD48L2RlZnM+PC9zdmc+";

  address internal constant LOCAL_MINTER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
  address internal constant LOCAL_DEV_ROYALTY_RECEIVER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

  address internal constant TESTNET_MINTER = 0x99211B61fc44e86ad9f05518C5138E3b59A60AFA;
  address internal constant TESTNET_DEV_ROYALTY_RECEIVER = 0x3cF262B414BAAf53b0b2fAc88154567fDF0AE851;

  address internal constant MAINNET_MINTER = 0xe52cCb0FE0500CC633B04b749622f4d608caDa1b;
  address internal constant MAINNET_DEV_ROYALTY_RECEIVER = 0x314E889E5B20d7D48B17c2890B44A42723e2F8a6;

  struct Config {
    address owner;
    address minter;
    address devRoyaltyReceiver;
  }

  function _getDeployedAddress(bytes memory creationCode, bytes memory constructorArgs) internal pure returns (address payable) {
    return payable(vm.computeCreate2Address(
      CREATE2_SALT, 
      hashInitCode(creationCode, constructorArgs)
    ));
  }

  function _getPixel8Config(Config memory cfg) internal pure returns (Pixel8.Config memory) {
    return Pixel8.Config({
      owner: cfg.owner,
      minter: cfg.minter,
      devRoyaltyReceiver: cfg.devRoyaltyReceiver,
      devRoyaltyFeeBips: 200, /* 2% */
      defaultImage: DEFAULT_PIXEL8_IMG,
      pirzePoolFeeBips: 300, /* 3% */
      gameOverRevealThreshold: 1764
    });
  }

  function _getMintSwapPoolConfig(Config memory cfg, address pixel8Address) internal pure returns (MintSwapPool.Config memory) {
    return MintSwapPool.Config({
      owner: cfg.owner,
      nft: pixel8Address,
      curve: PoolCurve({
        mintStartId: 1,
        mintEndId: 1764,
        startPriceWei: 0.00035 ether,
        /*
        Delta is equiv. to 1.004 <=> 0.4% 
        */
        delta: 1004000000000000000 
      })
    });
  }

  function _getScriptConfig() internal view returns (Config memory) {
    bytes32 env = keccak256(abi.encodePacked(vm.envString("ENV")));

    if (ENV_MAINNET == env) {
      return Config({
        owner: msg.sender,
        minter: MAINNET_MINTER,
        devRoyaltyReceiver: MAINNET_DEV_ROYALTY_RECEIVER
      });
    } else if (ENV_TESTNET == env) {
      return Config({
        owner: msg.sender,
        minter: TESTNET_MINTER,
        devRoyaltyReceiver: TESTNET_DEV_ROYALTY_RECEIVER
      });
    } else {
      return Config({
        owner: msg.sender,
        minter: LOCAL_MINTER,
        devRoyaltyReceiver: LOCAL_DEV_ROYALTY_RECEIVER
      });
    }
  }
}
