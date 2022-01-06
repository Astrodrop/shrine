// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.11;

import {DSTest} from "ds-test/test.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {Shrine} from "../Shrine.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {ShrineFactory} from "../ShrineFactory.sol";
import {MerkleTreeGenerator} from "./lib/MerkleTreeGenerator.sol";

contract ShrineTest is DSTest, MerkleTreeGenerator {
    uint256 constant EXAMPLE_TOTAL_SHARES = 1e18;
    uint256 constant EXAMPLE_USER_SHARES = 7e16;

    ShrineFactory factory;
    MockERC20 exampleToken;

    Shrine exampleShrine;
    bytes32[] exampleProof;

    function setUp() public {
        Shrine template = new Shrine();
        factory = new ShrineFactory(template);
        exampleToken = new MockERC20("Test Token", "TOK", 18);

        // generate example Merkle tree
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(
            keccak256(abi.encodePacked(address(this), EXAMPLE_USER_SHARES)),
            10,
            keccak256(abi.encodePacked(block.timestamp))
        );
        exampleProof = proof;

        // generate example shrine
        exampleShrine = factory.createShrine(
            address(this),
            Shrine.Ledger({
                merkleRoot: root,
                totalShares: EXAMPLE_TOTAL_SHARES
            }),
            "QmaCiEF9RzXrFGVoKtLFUrK6MUhUFgEm1dxpxoqDRFzENC"
        );

        // mint mock tokens to self
        exampleToken.mint(type(uint256).max);

        // set token approvals
        exampleToken.approve(address(exampleShrine), type(uint256).max);

        // offer example token
        exampleShrine.offer(exampleToken, type(uint128).max);
    }

    /// -------------------------------------------------------------------
    /// Gas benchmarking
    /// -------------------------------------------------------------------

    function testGas_offer(uint128 amount) public {
        exampleShrine.offer(exampleToken, amount);
    }

    function testGas_claim() public {
        exampleShrine.claim(
            Shrine.Version.wrap(1),
            exampleToken,
            Shrine.Champion.wrap(address(this)),
            EXAMPLE_USER_SHARES,
            exampleProof
        );
    }

    /// -------------------------------------------------------------------
    /// Correctness tests
    /// -------------------------------------------------------------------

    function testCorrectness_offerAndClaim(
        uint128 offerAmount,
        uint128 userShareAmount,
        uint8 treeHeightMinusOne,
        bytes32 randomness
    ) public {
        if (offerAmount == 0) offerAmount = 1;
        if (treeHeightMinusOne == 0) treeHeightMinusOne = 1;
        if (userShareAmount == 0) userShareAmount = 1;

        // setup
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(
            keccak256(
                abi.encodePacked(address(this), uint256(userShareAmount))
            ),
            treeHeightMinusOne,
            randomness
        );
        Shrine shrine = factory.createShrine(
            address(this),
            Shrine.Ledger({merkleRoot: root, totalShares: userShareAmount}),
            ""
        );
        MockERC20 testToken = new MockERC20("Test Token", "TOK", 18);

        // mint and offer tokens
        testToken.mint(offerAmount);
        testToken.approve(address(shrine), offerAmount);
        shrine.offer(testToken, offerAmount);

        // claim tokens
        uint256 claimedTokenAmount = shrine.claim(
            Shrine.Version.wrap(1),
            testToken,
            Shrine.Champion.wrap(address(this)),
            userShareAmount,
            proof
        );

        // verify tokens claimed
        assertEq(testToken.balanceOf(address(this)), offerAmount);
        assertEq(claimedTokenAmount, offerAmount);
    }
}
