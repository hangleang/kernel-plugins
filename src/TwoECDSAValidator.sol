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

    uint256 private constant OWNER_ONE_OFFSET = 0;
    uint256 private constant OWNER_TWO_OFFSET = 20;
    uint256 private constant OWNER_TWO_ENDPOS = 40;

    mapping(address account => TwoECDSAValidatorStorage accountStorage) public ecdsaValidatorStorage;

    function enable(bytes calldata _data) external override {
        address ownerOne = address(bytes20(_data[OWNER_ONE_OFFSET:OWNER_TWO_OFFSET]));
        address ownerTwo = address(bytes20(_data[OWNER_TWO_OFFSET:OWNER_TWO_ENDPOS]));

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
        bytes32 ethHash = userOpHash.toEthSignedMessageHash();

        (bytes memory signatureOne, bytes memory signatureTwo) = abi.decode(userOp.signature, (bytes, bytes));

        address recoveryOne = ethHash.recover(signatureOne);
        address recoveryTwo = ethHash.recover(signatureTwo);

        TwoECDSAValidatorStorage memory owners = ecdsaValidatorStorage[userOp.sender];

        bool ownerOneCheck = owners.ownerOne == recoveryOne;
        bool ownerTwoCheck = owners.ownerTwo == recoveryTwo;

        if (ownerOneCheck && ownerTwoCheck) return 0;

        return SIG_VALIDATION_FAILED;
    }

    function validateSignature(bytes32 hash, bytes calldata signature) external view override returns (uint256) {
        bytes32 ethHash = hash.toEthSignedMessageHash();

        (bytes memory signatureOne, bytes memory signatureTwo) = abi.decode(signature, (bytes, bytes));

        address recoveryOne = ethHash.recover(signatureOne);
        address recoveryTwo = ethHash.recover(signatureTwo);

        TwoECDSAValidatorStorage memory owners = ecdsaValidatorStorage[msg.sender];

        bool ownerOneCheck = owners.ownerOne == recoveryOne;
        bool ownerTwoCheck = owners.ownerTwo == recoveryTwo;

        if (ownerOneCheck && ownerTwoCheck) return 0;

        return SIG_VALIDATION_FAILED;
    }
}
