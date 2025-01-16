// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8 } from "./Pixel8.sol";
import { IMintSwapPool } from "./IMintSwapPool.sol";
import { PoolCurve } from "./Common.sol";
import { Auth } from "./Auth.sol";

/**
 * @notice Factory contract for creating Pixel8 instances
 */
contract Factory is Auth {
    event Pixel8Created(address indexed pixel8);

    // The authoriser for all Pixel8 instances
    address public immutable authoriser;
    uint public totalCreated;

    constructor(address _authoriser) {
        authoriser = _authoriser;
    }

    function getCreatePixel8SignableData(
        Pixel8.Config calldata pixel8Config,
        PoolCurve calldata poolCurve
    ) public pure returns (bytes memory) {
        return abi.encode(pixel8Config, poolCurve);
    }

    function createPixel8(
        address pool,
        Pixel8.Config calldata pixel8Config,
        PoolCurve calldata poolCurve,
        Auth.Signature calldata signature
    ) external returns (address) {
        // Verify signature from authoriser
        _assertValidSignature(
            msg.sender,
            authoriser,
            signature,
            getCreatePixel8SignableData(pixel8Config, poolCurve)
        );

        // Deploy new Pixel8 instance with modified config
        Pixel8.Config memory config = pixel8Config;
        config.owner = address(this);
        address pixel8 = address(new Pixel8(config));

        // Create pool for the NFT
        IMintSwapPool(pool).create(IMintSwapPool.PoolConfig({
            nft: pixel8,
            curve: poolCurve
        }));

        // Set pool on NFT
        Pixel8(payable(pixel8)).setPool(pool);
        unchecked { ++totalCreated; }

        emit Pixel8Created(pixel8);
        return pixel8;
    }
}
