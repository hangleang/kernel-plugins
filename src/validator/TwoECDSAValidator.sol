// from: https://github.com/eth-infinitism/trampoline/blob/two-owner-account/contracts/TwoOwnerAccount.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { IKernelValidator, UserOperation } from "kernel/validator/IValidator.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { SIG_VALIDATION_FAILED } from "kernel/utils/KernelHelper.sol";

struct TwoECDSAValidatorStorage {
    address ownerOne;
    address ownerTwo;
}

contract TwoECDSAValidator is IKernelValidator {
    using ECDSA for bytes32;

    event OwnerChanged(address indexed kernel, address indexed oldOwner, address indexed newOwner);

    mapping(address account => TwoECDSAValidatorStorage accountStorage) public ecdsaValidatorStorage;

    function enable(bytes calldata _data) external override {
        address ownerOne = address(bytes20(_data[0:20]));
        address ownerTwo = address(bytes20(_data[20:40]));

        TwoECDSAValidatorStorage memory owners = ecdsaValidatorStorage[msg.sender];

        if (ownerOne != owners.ownerOne) {
            address oldOwnerOne = owners.ownerOne;
            owners.ownerOne = ownerOne;
            emit OwnerChanged(msg.sender, oldOwnerOne, ownerOne);
        }

        if (ownerTwo != owners.ownerTwo) {
            address oldOwnerTwo = owners.ownerTwo;
            owners.ownerTwo = ownerTwo;
            emit OwnerChanged(msg.sender, oldOwnerTwo, ownerTwo);
        }

        ecdsaValidatorStorage[msg.sender] = owners;
    }

    function disable(bytes calldata) external override {
        delete ecdsaValidatorStorage[msg.sender];
    }

    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256
    )
        external
        view
        override
        returns (uint256)
    {
        return _validateSignature(userOpHash, userOp.signature, userOp.sender);
    }

    function validateSignature(bytes32 hash, bytes calldata signature) external view override returns (uint256) {
        return _validateSignature(hash, signature, msg.sender);
    }

    function _validateSignature(
        bytes32 hash,
        bytes calldata signature,
        address sender
    )
        internal
        view
        returns (uint256)
    {
        TwoECDSAValidatorStorage memory owners = ecdsaValidatorStorage[sender];
        (bytes memory signatureOne, bytes memory signatureTwo) = abi.decode(signature, (bytes, bytes));

        address recoveryOne = hash.recover(signatureOne);
        address recoveryTwo = hash.recover(signatureTwo);

        bool ownerOneCheck = owners.ownerOne == recoveryOne;
        bool ownerTwoCheck = owners.ownerTwo == recoveryTwo;

        if (ownerOneCheck && ownerTwoCheck) return 0;

        bytes32 ethHash = hash.toEthSignedMessageHash();
        recoveryOne = ethHash.recover(signatureOne);
        recoveryTwo = ethHash.recover(signatureTwo);

        ownerOneCheck = owners.ownerOne == recoveryOne;
        ownerTwoCheck = owners.ownerTwo == recoveryTwo;

        if (ownerOneCheck && ownerTwoCheck) return 0;

        return SIG_VALIDATION_FAILED;
    }
}
