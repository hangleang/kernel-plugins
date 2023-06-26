// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "kernel/validator/IValidator.sol";
import "account-abstraction/core/Helpers.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { SIG_VALIDATION_FAILED } from "kernel/utils/KernelHelper.sol";
import { KernelStorage } from "kernel/abstract/KernelStorage.sol";

struct SocialRecoveryValidatorStorage {
    address owner;
    // address[] guardians;
    uint8 threshold;
    uint8 approvalCount;
    uint48 pausedUntil;
    address potentialOwner;
}

/**
 * @title SocialRecoveryValidator
 * @author hangleang
 * @notice Not for production, just PoC
 * @dev inspire_by: [
 * - https://github.com/zerodevapp/kernel/blob/main/src/validator/KillSwitchValidator.sol
 * - https://github.com/zerodevapp/kernel/blob/main/src/validator/MultiECDSAValidator.sol
 */
contract SocialRecoveryValidator is IKernelValidator {
    event GuardianAdded(address indexed kernel, address indexed guardian);
    event GuardianRemoved(address indexed kernel, address indexed guardian);
    event SocialRecoveryValidatorStorageChanges(address indexed kernel, address indexed owner, uint8 threshold);
    event OwnerChanged(address indexed kernel, address indexed oldOwner, address indexed newOwner);

    mapping(address kernel => SocialRecoveryValidatorStorage validatorStorage) public socialRecoveryValidatorStorage;

    mapping(address kernel => BitMaps.BitMap bitmap) private approvals;

    mapping(address guardian => mapping(address kernel => bool isTrue)) public isGuardian;

    function enable(bytes calldata _data) external override {
        address kernel = msg.sender;
        SocialRecoveryValidatorStorage memory validatorStorage = socialRecoveryValidatorStorage[kernel];
        address owner = address(bytes20(_data[0:20]));
        uint8 threshold = uint8(bytes1(_data[20:21]));
        (address[] memory guardians) = abi.decode(_data[21:], (address[]));
        require(threshold <= guardians.length, "SocialRecoveryValidator: invalid threshold");

        // set validatorStorage, update storage
        validatorStorage.owner = owner;
        validatorStorage.threshold = threshold;
        // validatorStorage.guardians = guardians;
        socialRecoveryValidatorStorage[kernel] = validatorStorage;

        for (uint256 i = 0; i < guardians.length; i++) {
            isGuardian[guardians[i]][kernel] = true;
            emit GuardianAdded(kernel, guardians[i]);
        }

        emit SocialRecoveryValidatorStorageChanges(msg.sender, owner, threshold);
    }

    function disable(bytes calldata _data) external override {
        address[] memory quardians = abi.decode(_data, (address[]));
        for (uint256 i = 0; i < quardians.length; i++) {
            isGuardian[quardians[i]][msg.sender] = false;
            emit GuardianRemoved(msg.sender, quardians[i]);
        }
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
        // address recovered;
        // bytes calldata signature;
        SocialRecoveryValidatorStorage memory validatorStorage = socialRecoveryValidatorStorage[userOp.sender];

        // signature from one of the guardians
        if (userOp.signature.length > 65) {
            require(bytes4(userOp.callData[0:4]) != KernelStorage.disableMode.selector);
            uint48 pausedUntil = uint48(bytes6(userOp.signature[0:6]));
            require(pausedUntil > validatorStorage.pausedUntil, "SocialRecoveryValidator: invalid pausedUntil");
            address newOwner = address(bytes20(userOp.signature[6:26]));
            bytes calldata signature = userOp.signature[26:91];

            // check signer & approvals
            address recovered = ECDSA.recover(userOpHash, signature);
            if (!isGuardian[recovered][userOp.sender]) return SIG_VALIDATION_FAILED;
            uint256 signerIndex = uint256(uint160(recovered));
            require(!approvals[userOp.sender].get(signerIndex), "MultisigAuthorizationValidator: already approved");

            // check if potentialOwner is empty or same with existing one, not yet approved
            require(validatorStorage.potentialOwner == address(0) || validatorStorage.potentialOwner == newOwner);

            // update approvalCount, potentialOwner, isApproved
            validatorStorage.approvalCount = validatorStorage.approvalCount + 1;

            // check if hit threshold, change owner and reset state
            if (validatorStorage.approvalCount >= validatorStorage.threshold) {
                validatorStorage.owner = newOwner;
                validatorStorage.pausedUntil = pausedUntil;
                validatorStorage.approvalCount = 0;
                validatorStorage.potentialOwner = address(0);

                // reset approvals states
                delete approvals[userOp.sender];
            } else {
                validatorStorage.potentialOwner = newOwner;
                quardianApprovalStorage[recovered][userOp.sender].isApproved = true;

                // TODO: should prevent from execution before hit threshold signatures
            }

            socialRecoveryValidatorStorage[userOp.sender] = validatorStorage;
            return 0;
        } else {
            // signer = validatorStorage.owner;
            bytes calldata signature = userOp.signature;
            address recovered = ECDSA.recover(userOpHash, signature);

            // after, check signature is from owner or one of the guardians
            if (recovered == validatorStorage.owner) {
                // address(0) attack has been resolved in ECDSA library
                return _packValidationData(false, 0, validatorStorage.pausedUntil);
            }

            bytes32 hash = ECDSA.toEthSignedMessageHash(userOpHash);
            recovered = ECDSA.recover(hash, signature);
            if (recovered != validatorStorage.owner) {
                return SIG_VALIDATION_FAILED;
            }
            return _packValidationData(false, 0, validatorStorage.pausedUntil);
        }

        // // after, check signature is from owner or one of the guardians
        // if (_checkOwnerOrGuardian(userOp.sender, recovered)) {
        //     // address(0) attack has been resolved in ECDSA library
        //     return _packValidationData(false, 0, validatorStorage.pausedUntil);
        // }

        // bytes32 hash = ECDSA.toEthSignedMessageHash(userOpHash);
        // recovered = ECDSA.recover(hash, signature);
        // if (_checkOwnerOrGuardian(userOp.sender, recovered)) {
        //     return SIG_VALIDATION_FAILED;
        // }
        // return _packValidationData(false, 0, validatorStorage.pausedUntil);
    }

    function validateSignature(bytes32 hash, bytes calldata signature) external view override returns (uint256) {
        SocialRecoveryValidatorStorage memory validatorStorage = socialRecoveryValidatorStorage[msg.sender];
        return _packValidationData(
            validatorStorage.owner != ECDSA.recover(hash, signature), 0, validatorStorage.pausedUntil
        );
    }

    // function _checkOwnerOrGuardian(address kernel, address recovered) internal view returns (bool) {
    //     return (
    //         recovered == socialRecoveryValidatorStorage[kernel].owner
    //             || quardianApprovalStorage[recovered][kernel].isGuardian
    //     );
    // }
}
