// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "kernel/validator/IValidator.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import { SIG_VALIDATION_FAILED } from "kernel/utils/KernelHelper.sol";

import { IMultisigExecutor } from "../interfaces/IMultisigExecutor.sol";

struct MultisigAuthorizationStorage {
    bool enabled;
    // address owner;
    uint8 threshold;
}

struct Operation {
    // address to;
    // uint256 value;
    bytes callData;
    bool validated;
    uint8 approvalsCount;
}

/**
 * @title MultisigAuthorizationValidator
 * @author hangleang
 * @notice Not for production, just PoC
 */
contract MultisigAuthorizationValidator is IKernelValidator {
    using BitMaps for BitMaps.BitMap;

    // event OwnerChanged(address indexed kernel, address indexed oldOwner, address indexed newOwner);
    event GuardianAdded(address indexed kernel, address indexed guardian);

    event GuardianRemoved(address indexed kernel, address indexed guardian);

    event ThresholdChanged(address indexed kernel, uint8 threshold);

    mapping(address kernel => MultisigAuthorizationStorage validatorStorage) public multisigAuthorizationStorage;

    mapping(address guardian => mapping(address kernel => bool isTrue)) public isGuardian;

    mapping(address kernel => mapping(uint256 nonce => BitMaps.BitMap bitmap)) private approvals;

    mapping(address kernel => mapping(uint256 nonce => Operation op)) private operations;

    function enable(bytes calldata _data) external override {
        address kernel = msg.sender;
        uint8 threshold = uint8(bytes1(_data[0:1]));
        uint8 count = uint8(bytes1(_data[1:2]));

        // 2 + (20 * count) => addressOffset + (addressSize * count)
        address[] memory guardians = abi.decode(_data[2:], (address[]));

        require(count == guardians.length && threshold <= count, "MultisigAuthorizationValidator: invalid threshold");
        multisigAuthorizationStorage[kernel] = MultisigAuthorizationStorage(true, threshold);
        emit ThresholdChanged(kernel, threshold);

        for (uint256 i = 0; i < count; i++) {
            isGuardian[guardians[i]][kernel] = true;
            emit GuardianAdded(kernel, guardians[i]);
        }
    }

    function disable(bytes calldata _data) external override {
        address kernel = msg.sender;
        delete multisigAuthorizationStorage[kernel];

        address[] memory accounts = abi.decode(_data, (address[]));
        for (uint256 i = 0; i < accounts.length; i++) {
            require(isGuardian[accounts[i]][kernel], "MultisigAuthorizationValidator: not guardian");
            isGuardian[accounts[i]][kernel] = false;
            emit GuardianRemoved(kernel, accounts[i]);
        }
        emit ThresholdChanged(kernel, 0);
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256
    )
        external
        override
        returns (uint256)
    {
        // check if kernel has enabled this plugin
        MultisigAuthorizationStorage memory validatorStorage = multisigAuthorizationStorage[userOp.sender];
        if (!validatorStorage.enabled) return SIG_VALIDATION_FAILED;

        // extract signer address and actual signature, check if one of guardians, also with valid signature
        (address signer, bytes memory signature) = abi.decode(userOp.signature, (address, bytes));
        bytes32 hash = ECDSA.toEthSignedMessageHash(userOpHash);
        if (!(isGuardian[signer][userOp.sender] && SignatureChecker.isValidSignatureNow(signer, hash, signature))) {
            return SIG_VALIDATION_FAILED;
        }

        Operation memory op;
        uint256 nonce;
        bytes4 sig = bytes4(userOp.callData[0:4]);
        if (sig == IMultisigExecutor.submitOperation.selector) {
            nonce = userOp.nonce;
            op = Operation(userOp.callData, false, 0);

            address to = address(bytes20(userOp.callData[4:24]));
            if (to == userOp.sender) {
                sig = bytes4(userOp.callData[56:60]); // funcSig + toAddress + value

                if (sig == IMultisigExecutor.setThreshold.selector) {
                    uint8 threshold = uint8(bytes1(userOp.callData[60:61]));
                } else if (sig == IMultisigExecutor.setGuardians.selector) {
                    uint8 count = uint8(bytes1(userOp.callData[60:61]));
                    address[] memory guardians = abi.decode(userOp.callData[61:61 + (count * 20)], (address[]));
                } else if (sig == IMultisigExecutor.setGuardiansAndThreshold.selector) {
                    uint8 threshold = uint8(bytes1(userOp.callData[60:61]));
                    uint8 count = uint8(bytes1(userOp.callData[61:62]));
                    address[] memory guardians = abi.decode(userOp.callData[62:62 + (count * 20)], (address[]));
                }

                // TODO: need to store pending value of threshold, list of guardians to be added
            }
        } else if (
            sig == IMultisigExecutor.confirmOperation.selector || sig == IMultisigExecutor.executeOperation.selector
                || sig == IMultisigExecutor.revokeConfirmation.selector
        ) {
            nonce = uint256(bytes32(userOp.callData[4:36]));
            op = operations[userOp.sender][nonce];

            if (sig == IMultisigExecutor.confirmOperation.selector) {
                // check if not yet approved
                uint256 signerIndex = uint256(uint160(signer));
                require(
                    !approvals[userOp.sender][userOp.nonce].get(signerIndex),
                    "MultisigAuthorizationValidator: already approved"
                );
                approvals[userOp.sender][nonce].setTo(signerIndex, true);
                op.approvalsCount++;
            } else if (sig == IMultisigExecutor.revokeConfirmation.selector) {
                // check if not yet approved
                uint256 signerIndex = uint256(uint160(signer));
                require(
                    approvals[userOp.sender][userOp.nonce].get(signerIndex),
                    "MultisigAuthorizationValidator: not already approved"
                );
                approvals[userOp.sender][nonce].setTo(signerIndex, false);
                op.approvalsCount--;
            } else {
                // check if hit threshold, reset state
                if (op.approvalsCount == validatorStorage.threshold) {
                    delete approvals[userOp.sender][nonce];
                }
            }
        }

        // update operation storage and return success
        operations[userOp.sender][nonce] = op;
        return 0;
    }

    function validateSignature(bytes32, bytes calldata) external pure override returns (uint256) {
        revert("not implemented");
    }
}
