// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.11;

abstract contract Initializable {
    error Initializable_AlreadyInitialized();

    bool private initialized;

    modifier initializer() {
        if (initialized) revert Initializable_AlreadyInitialized();
        _;
        initialized = true;
    }
}
