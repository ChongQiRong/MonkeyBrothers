// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IERC165.sol";

abstract contract ERC165 is IERC165 {
    // Mapping of interface id to whether or not it's supported
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor() {
        // Register the supported interface
        _registerInterface(type(IERC165).interfaceId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`.
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}
