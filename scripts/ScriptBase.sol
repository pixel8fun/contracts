// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Script, console2 as c } from "forge-std/Script.sol";
import { Vm } from "forge-std/Vm.sol";
import { Strings } from "openzeppelin/utils/Strings.sol";
import { Pixel8 } from "src/Pixel8.sol";
import { LotteryNFT } from "src/LotteryNFT.sol";
import { MintSwapPool } from "src/MintSwapPool.sol";
import { PoolCurve } from "src/Common.sol";

contract ScriptBase is Script {
  bytes32 internal constant ENV_MAINNET = keccak256(abi.encodePacked("mainnet"));
  bytes32 internal constant ENV_TESTNET = keccak256(abi.encodePacked("testnet"));

  bytes32 internal constant CREATE2_SALT = keccak256("Pixel8.deployment.salt4");
  string internal constant DEFAULT_PIXEL8_IMG = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9Im5vbmUiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIj48cGF0aCBmaWxsPSIjRDhEOEQ4IiBmaWxsLW9wYWNpdHk9Ii41IiBkPSJNMCAwaDUxMnY1MTJIMHoiLz48ZyBjbGlwLXBhdGg9InVybCgjYSkiPjxwYXRoIGZpbGw9IiMzMTMwMzAiIGQ9Ik0xOTcuNiAzNTJoMTE1LjhjNC44IDAgOC43LTMuOSA4LjctOC43VjI0NWMwLTQuOC00LTguNy04LjctOC43aC04Ljd2LTI2YTQ5LjMgNDkuMyAwIDAgMC05OC40IDB2MjZoLTguN2E4LjcgOC43IDAgMCAwLTguNyA4Ljd2OTguNGMwIDQuOCA0IDguNyA4LjcgOC43Wm02Ni42LTU1djExLjZhOC43IDguNyAwIDEgMS0xNy40IDBWMjk3YTE0LjUgMTQuNSAwIDEgMSAxNy40IDBabS00MC41LTg2LjhhMzEuOSAzMS45IDAgMCAxIDYzLjYgMHYyNmgtNjMuNnYtMjZaIi8+PC9nPjxkZWZzPjxjbGlwUGF0aCBpZD0iYSI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTE2MCAxNjFoMTkxdjE5MUgxNjB6Ii8+PC9jbGlwUGF0aD48L2RlZnM+PC9zdmc+";
  string internal constant DEFAULT_LOTTERY_IMG = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIGZpbGw9Im5vbmUiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIj48cGF0aCBmaWxsPSIjMDAwIiBkPSJNMCAwaDUxMnY1MTJIMHoiLz48ZyBmaWxsPSIjRDRDNzUxIiBjbGlwLXBhdGg9InVybCgjYSkiPjxwYXRoIGQ9Ik00MDYuMyAyMjAuNGMtMy0zLTMtNy43IDAtMTAuNmE2IDYgMCAwIDAgMC04LjVsLTE5LjItMTlhNiA2IDAgMCAwLTguNCAwIDcuNiA3LjYgMCAwIDEtMTAuNy0xMC44IDYgNiAwIDAgMCAwLTguNEwzNDkgMTQ0YTYgNiAwIDAgMC04LjUgMCA3LjYgNy42IDAgMCAxLTEwLjctMTAuNyA2IDYgMCAwIDAgMC04LjRsLTE5LjEtMTkuMmE2IDYgMCAwIDAtOC40IDBjLTMgMy03LjggMy0xMC43IDBhNiA2IDAgMCAwLTguNSAwTDEwNC43IDI4NC4xYTYgNiAwIDAgMCAwIDguNWMzIDMgMyA3LjcgMCAxMC42YTYgNiAwIDAgMCAwIDguNWwxOS4yIDE5YTYgNiAwIDAgMCA4LjQgMCA3LjYgNy42IDAgMCAxIDEwLjcgMTAuOCA2IDYgMCAwIDAgMCA4LjRsMTkgMTkuMWE2IDYgMCAwIDAgOC41IDAgNy42IDcuNiAwIDAgMSAxMC43IDEwLjcgNiA2IDAgMCAwIDAgOC40bDE5LjEgMTkuMmE2IDYgMCAwIDAgOC41IDAgNy41IDcuNSAwIDAgMSAxMC42IDAgNiA2IDAgMCAwIDguNSAwbDE3OC40LTE3OC40YTYgNiAwIDAgMCAwLTguNVptLTEyIDMuNkwyMjMgMzk1LjNhMTkuNCAxOS40IDAgMCAwLTE3LjggMGwtMTItMTJhMTkuNCAxOS40IDAgMCAwLTMuNi0yMi43QTE5LjUgMTkuNSAwIDAgMCAxNjcgMzU3bC0xMi0xMmExOS40IDE5LjQgMCAwIDAtMy42LTIyLjYgMTkuMyAxOS4zIDAgMCAwLTIyLjctMy42bC0xMi0xMmExOS42IDE5LjYgMCAwIDAgMC0xNy44TDI4OCAxMTcuN2ExOS42IDE5LjYgMCAwIDAgMTcuOCAwbDEyIDEyQTE5LjUgMTkuNSAwIDAgMCAzNDQgMTU2bDEyIDEyYTE5LjQgMTkuNCAwIDAgMCAzLjYgMjIuNiAxOS4zIDE5LjMgMCAwIDAgMjIuNyAzLjZsMTIgMTJhMTkuNiAxOS42IDAgMCAwIDAgMTcuOFoiLz48cGF0aCBkPSJNMjkxLjYgMTM5LjRhNiA2IDAgMCAwLTguNSAwTDEzOC40IDI4NC4xYTYgNiAwIDAgMCAwIDguNUwxNjAgMzE0YTYgNiAwIDAgMCA4LjQtOC40bC0xNy4zLTE3LjQgMTM2LjItMTM2LjIgNzIuNiA3Mi42LTEzNi4yIDEzNi4yLTE3LjQtMTcuM2E2IDYgMCAwIDAtOC40IDguNGwyMS41IDIxLjZhNiA2IDAgMCAwIDguNSAwbDE0NC43LTE0NC43YTYgNiAwIDAgMCAwLTguNWwtODEtODFaIi8+PHBhdGggZD0ibTIwNy4yIDMxMSA1LjQtMi4yYTQgNCAwIDAgMSAzLjIgMCA0IDQgMCAwIDEgMi4yIDUuMyA0IDQgMCAwIDEtMi4yIDIuM2wtMi44IDEuMWE2IDYgMCAxIDAgNC42IDExbDIuNy0xLjEgMS4zLS42IDEuNSAxLjVhNiA2IDAgMCAwIDguNCAwIDYgNiAwIDAgMCAwLTguNWwtMi4yLTJhMTUuOSAxNS45IDAgMCAwLTktMjAgMTYgMTYgMCAwIDAtMTIuMyAwbC01LjQgMi4yYTQuMSA0LjEgMCAwIDEtMy4xLTcuNmwyLjctMS4xYTYgNiAwIDEgMC00LjYtMTFsLTIuNyAxLjEtMS4zLjYtMS40LTEuNWE2IDYgMCAwIDAtOC41IDguNGwyLjIgMi4yYTE2IDE2IDAgMCAwIDIxLjMgMjBaTTI0OC45IDMwMi44YTYgNiAwIDAgMCA0LjItMS44bDIyLjYtMjIuNmE2IDYgMCAxIDAtOC40LTguNGwtMjIuNiAyMi42YTYgNiAwIDAgMCA0LjIgMTAuMlpNMjU4LjkgMjUzLjFhNiA2IDAgMCAwLTguNCAwbC0yMi43IDIyLjZhNiA2IDAgMCAwIDguNSA4LjVsMjIuNi0yMi43YTYgNiAwIDAgMCAwLTguNFpNMjcxIDE5OC45bC02MCA2MGE2IDYgMCAwIDAgOC40IDguNGw2MC02MGE2IDYgMCAwIDAtOC40LTguNFpNMjY1LjYgMjQwLjVjMCAxLjYuNiAzIDEuNyA0LjJsMTYuOSAxNi44YTYgNiAwIDAgMCA4LjQgMGwzOS41LTM5LjRhNiA2IDAgMCAwIDAtOC41bC0xNi45LTE2LjhhNiA2IDAgMCAwLTguNCAwbC0zOS41IDM5LjVhNiA2IDAgMCAwLTEuNyA0LjJabTQ1LjQtMzEgOC40IDguNC0zMSAzMS04LjUtOC40IDMxLjEtMzFaTTMwMC4xIDE4NC4yYTYgNiAwIDEgMC0xMiAwIDYgNiAwIDAgMCAxMiAwWk0xODMuMiAzMjIuOWE2IDYgMCAxIDAgMCAxMS45IDYgNiAwIDAgMCAwLTEyWiIvPjwvZz48ZGVmcz48Y2xpcFBhdGggaWQ9ImEiPjxwYXRoIGZpbGw9IiNmZmYiIGQ9Ik0xMDMgMTA0aDMwNXYzMDVIMTAzeiIvPjwvY2xpcFBhdGg+PC9kZWZzPjwvc3ZnPg==";

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
      devRoyaltyFeeBips: 500, /* 500 bips = 5% */
      defaultImage: DEFAULT_PIXEL8_IMG,
      lotteryPotFeeBips: 500, /* 500 bips = 5% */
      lotteryDeadline: 1735689600, /* 2025-01-01 00:00:00 - keep it fixed so that CREATE2 returns same address each time */
      lotteryRevealThreshold: 9261 /* level 1 + level 2 + level 3 tiles */
    });
  }

  function _getLotteryNftConfig(Config memory cfg, address pixel8Address) internal pure returns (LotteryNFT.Config memory) {
    return LotteryNFT.Config({
      owner: cfg.owner,
      minter: pixel8Address,
      defaultImage: DEFAULT_LOTTERY_IMG,
      royaltyReceiver: cfg.devRoyaltyReceiver,
      royaltyFeeBips: 500 /* 500 bips = 5% */
    });
  }

  function _getMintSwapPoolConfig(Config memory cfg, address pixel8Address) internal pure returns (MintSwapPool.Config memory) {
    return MintSwapPool.Config({
      owner: cfg.owner,
      nft: pixel8Address,
      curve: PoolCurve({
        mintStartId: 801,
        mintEndId: 7056,
        startPriceWei: 0.01 ether,
        /*
        Delta is equiv. to 1.0007 => increase by 0.07% 
        */
        delta: 1000700000000000000 
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
