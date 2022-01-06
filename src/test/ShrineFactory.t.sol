// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import {DSTest} from "ds-test/test.sol";

import {Shrine} from "../Shrine.sol";
import {ShrineFactory} from "../ShrineFactory.sol";

contract ShrineFactoryTest is DSTest {
    ShrineFactory factory;

    function setUp() public {
        Shrine template = new Shrine();
        factory = new ShrineFactory(template);
    }

    function test_createShrine() public {
        factory.createShrine(
            address(this),
            Shrine.Ledger({
                merkleRoot: 0x805c7069af26b020f439d4153b0828b0c848f2f023dff7254dd2df228e27b65d,
                totalShares: 1e27
            }),
            "QmaCiEF9RzXrFGVoKtLFUrK6MUhUFgEm1dxpxoqDRFzENC"
        );
    }
}
