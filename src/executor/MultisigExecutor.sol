// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import { IMultisigExecutor } from "../interfaces/IMultisigExecutor.sol";
import { Exec } from "kernel/utils/Exec.sol";

/// @dev The diamond storage for MultisigExecutor
library OperationsStorage {
    bytes32 constant OPERATIONS_POSITION = keccak256("org.kernel-plugins.multisig.operations");

    struct Operation {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint8 approvalsCount;
    }

    struct Operations {
        mapping(uint256 nonce => Operation op) operations;
    }

    function getStorage() internal pure returns (Operations storage ops) {
        bytes32 position = OPERATIONS_POSITION;
        assembly {
            ops.slot := position
        }
    }
}

/**
 * @title MultisigExecutor
 * @author hangleang
 * @notice Not for production, just PoC
 */

contract MultisigExecutor is IMultisigExecutor {
    event SubmitOperation(uint256 indexed nonce, address indexed to, uint256 value, bytes data);
    event ConfirmOperation(uint256 indexed nonce);
    event RevokeConfirmation(uint256 indexed nonce);
    event ExecuteOperation(uint256 indexed nonce);

    modifier opExists(uint256 nonce) {
        OperationsStorage.Operations storage ops = OperationsStorage.getStorage();
        require(ops.operations[nonce].to != address(0), "op does not exist");
        _;
    }

    modifier notExecuted(uint256 nonce) {
        OperationsStorage.Operations storage ops = OperationsStorage.getStorage();
        require(!ops.operations[nonce].executed, "op already executed");
        _;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "only selfcall");
        _;
    }

    function submitOperation(address to, uint256 value, bytes calldata data, uint256 nonce) external override {
        OperationsStorage.Operations storage ops = OperationsStorage.getStorage();
        ops.operations[nonce] = OperationsStorage.Operation(to, value, data, false, 0);

        emit SubmitOperation(nonce, to, value, data);
    }

    function confirmOperation(uint256 nonce) external override opExists(nonce) {
        OperationsStorage.Operations storage ops = OperationsStorage.getStorage();
        ops.operations[nonce].approvalsCount++;

        emit ConfirmOperation(nonce);
    }

    function executeOperation(uint256 nonce) external override opExists(nonce) notExecuted(nonce) {
        OperationsStorage.Operations storage ops = OperationsStorage.getStorage();
        OperationsStorage.Operation memory op = ops.operations[nonce];

        (bool success, bytes memory ret) = Exec.call(op.to, op.value, op.data);
        if (!success) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
        ops.operations[nonce].executed = success;

        emit ExecuteOperation(nonce);
    }

    function revokeConfirmation(uint256 nonce) external override opExists(nonce) notExecuted(nonce) {
        OperationsStorage.Operations storage ops = OperationsStorage.getStorage();
        ops.operations[nonce].approvalsCount--;

        emit RevokeConfirmation(nonce);
    }

    function setThreshold(uint8) external view override onlySelf { }

    function setGuardians(uint8, address[] memory) external view override onlySelf { }

    function setGuardiansAndThreshold(uint8, uint8, address[] memory) external view override onlySelf { }

    // function setOwner(address newOwner) external override { }
}
