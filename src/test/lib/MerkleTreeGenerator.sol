// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.11;

contract MerkleTreeGenerator {
    function generateMerkleTree(
        bytes32 leaf,
        uint8 treeHeightMinusOne,
        bytes32 randomness
    ) internal pure returns (bytes32 root, bytes32[] memory proof) {
        bytes32 computedHash = leaf;
        proof = new bytes32[](treeHeightMinusOne);
        for (uint256 i = 0; i < treeHeightMinusOne; i++) {
            // use the randomness as the proof element
            proof[i] = randomness;

            // compute hash up the tree
            if (computedHash <= randomness) {
                // Hash(current computed hash + current element of the proof)
                computedHash = _efficientHash(computedHash, randomness);
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = _efficientHash(randomness, computedHash);
            }

            // refresh randomness
            randomness = keccak256(abi.encodePacked(randomness));
        }
        root = computedHash;
    }

    function _efficientHash(bytes32 a, bytes32 b)
        private
        pure
        returns (bytes32 value)
    {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}
