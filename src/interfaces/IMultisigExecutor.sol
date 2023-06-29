// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

/**
 * @title IMultisigExecutor
 * @author hangleang
 * @notice Not for production, just PoC
 */
interface IMultisigExecutor {
    function submitOperation(address to, uint256 value, bytes calldata data, uint256 nonce) external;

    function confirmOperation(uint256 nonce) external;

    function executeOperation(uint256 nonce) external;

    function revokeConfirmation(uint256 nonce) external;

    function setThreshold(uint8 threshold) external;

    function setGuardians(uint8 count, address[] memory guardians) external;

    function setGuardiansAndThreshold(uint8 threshold, uint8 count, address[] memory guardians) external;

    // function setOwner(address newOwner) external;
}
