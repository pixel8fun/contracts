// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.24;

import { Pixel8 } from "./Pixel8.sol";
import { IMintSwapPool } from "./IMintSwapPool.sol";
import { PoolCurve } from "./Common.sol";
import { Auth } from "./Auth.sol";
import { Strings } from "openzeppelin/utils/Strings.sol";

/**
 * @notice Factory contract for creating Pixel8 instances
 */
contract Factory is Auth {
    event Pixel8Created(address indexed pixel8);

    uint public totalCreated;

    // The authoriser for all Pixel8 instances
    address public immutable authoriser;

    constructor(address _authoriser) {
        authoriser = _authoriser;
    }

    function getCreatePixel8SignableData(
        Pixel8.Config memory pixel8Config,
        PoolCurve memory poolCurve
    ) public pure returns (bytes memory) {
        return abi.encode(pixel8Config, poolCurve);
    }

    function createPixel8(
        address pool,
        Pixel8.Config memory pixel8Config,
        PoolCurve memory poolCurve,
        Auth.Signature memory signature
    ) external returns (address) {
        // Verify signature from authoriser
        _assertValidSignature(
            msg.sender,
            authoriser,
            signature,
            getCreatePixel8SignableData(pixel8Config, poolCurve)
        );

        // Override owner in config
        pixel8Config.owner = address(this);

        // set name
        totalCreated++;
        string memory totalCreatedStr = Strings.toString(totalCreated);
        pixel8Config.name = string.concat("Pixel8_", totalCreatedStr);
        pixel8Config.symbol = string.concat("PIXEL8_", totalCreatedStr);

        // Deploy new Pixel8 instance
        address pixel8 = address(new Pixel8(pixel8Config));

        // Create pool for the NFT
        IMintSwapPool(pool).create(IMintSwapPool.PoolConfig({
            nft: pixel8,
            curve: poolCurve
        }));

        // Set pool on NFT
        Pixel8(payable(pixel8)).setPool(pool);

        emit Pixel8Created(pixel8);
        return pixel8;
    }
}
