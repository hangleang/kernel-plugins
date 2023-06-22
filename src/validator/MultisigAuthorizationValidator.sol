// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "kernel/validator/IValidator.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import { SIG_VALIDATION_FAILED } from "kernel/utils/KernelHelper.sol";

/**
 * @title MultisigAuthorizationValidator
 * @author hangleang
 * @notice Not for production, just PoC
 */
contract MultisigAuthorizationValidator is IKernelValidator {
    using BitMaps for BitMaps.BitMap;

    event GuardianAdded(address indexed kernel, address indexed guardian);
    event GuardianRemoved(address indexed kernel, address indexed guardian);
    event ThresholdChanged(address indexed kernel, uint8 threshold);

    struct MultisigAuthorizationStorage {
        bool enabled;
        uint8 threshold;
        uint8 approvalsCount;
    }

    mapping(address kernel => MultisigAuthorizationStorage validatorStorage) public multisigAuthorizationStorage;
    mapping(address kernel => BitMaps.BitMap bitmap) private approvals;
    mapping(address guardian => mapping(address kernel => bool isTrue)) public isGuardian;

    function enable(bytes calldata _data) external override {
        address kernel = msg.sender;
        uint8 threshold = uint8(bytes1(_data[0:1]));
        uint8 count = uint8(bytes1(_data[1:2]));

        // 2 + (20 * count) => addressOffset + (addressSize * count)
        address[] memory guardians = abi.decode(_data[2:], (address[]));

        require(count == guardians.length && threshold <= count, "MultisigAuthorizationValidator: invalid threshold");
        multisigAuthorizationStorage[kernel] = MultisigAuthorizationStorage(true, threshold, 0);
        for (uint256 i = 0; i < count; i++) {
            isGuardian[guardians[i]][kernel] = true;
            emit GuardianAdded(kernel, guardians[i]);
        }
        emit ThresholdChanged(kernel, threshold);
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
        MultisigAuthorizationStorage memory validatorStorage = multisigAuthorizationStorage[userOp.sender];
        if (!validatorStorage.enabled) return SIG_VALIDATION_FAILED;

        // extract signer address and signature, check if one of guardians, also with valid signature
        (address signer, bytes memory signature) = abi.decode(userOp.signature, (address, bytes));
        bytes32 hash = ECDSA.toEthSignedMessageHash(userOpHash);
        if (!(isGuardian[signer][userOp.sender] && SignatureChecker.isValidSignatureNow(signer, hash, signature))) {
            return SIG_VALIDATION_FAILED;
        }

        // check if not yet approved
        uint256 signerIndex = uint256(uint160(signer));
        require(!approvals[userOp.sender].get(signerIndex), "MultisigAuthorizationValidator: already approved");
        validatorStorage.approvalsCount++;

        // check if hit threshold, reset state
        if (validatorStorage.approvalsCount == validatorStorage.threshold) {
            validatorStorage.approvalsCount = 0;
            delete approvals[userOp.sender];
        } else {
            approvals[userOp.sender].setTo(signerIndex, true);

            // TODO: should prevent from execution before hit threshold signatures
        }

        // update storage and return success
        multisigAuthorizationStorage[userOp.sender] = validatorStorage;
        return 0;
    }

    function validateSignature(bytes32, bytes calldata) external pure override returns (uint256) {
        revert("not implemented");
    }
}
