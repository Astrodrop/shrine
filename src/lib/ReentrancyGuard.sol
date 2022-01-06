// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.11;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @notice Gas optimized reentrancy protection for smart contracts.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/utils/ReentrancyGuard.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
abstract contract ReentrancyGuard is Initializable {
    error ReentrancyGuard_Reentrancy();

    uint256 private locked;

    modifier nonReentrant() {
        if (locked != 1) revert ReentrancyGuard_Reentrancy();

        locked = 2;

        _;

        locked = 1;
    }

    function __ReentrancyGuard_init() internal initializer {
        locked = 1;
    }
}
