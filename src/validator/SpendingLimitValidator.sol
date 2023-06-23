// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "kernel/validator/IValidator.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { SIG_VALIDATION_FAILED } from "kernel/utils/KernelHelper.sol";

// enum SpendingLimitType {
//     Value,
//     Request
// }

struct SpendingLimitValidatorStorage {
    // SpendingLimitType spendingLimitType;
    bytes4 selector;
    address owner;
    uint256 thresholdValue;
}

struct SpendingLimitState {
    // state
    uint256 spent;
    uint256 eodTimestamp; // end of day
}

/**
 * @title SpendingLimitValidator
 * @author hangleang
 * @notice Not for production, just PoC
 */
contract SpendingLimitValidator is IKernelValidator {
    event ThresholdValueChanged(address indexed kernel, address indexed token, uint256 value);

    uint48 private constant DAY_IN_SECONDS = 24 * 60 * 60;

    mapping(address kernel => mapping(address token => SpendingLimitValidatorStorage validatorStorage)) public
        spendingLimitValidatorStorage;

    mapping(address kernel => mapping(address token => SpendingLimitState state)) public spendingLimitState;

    function enable(bytes calldata _data) external override {
        address kernel = msg.sender;
        // (address owner, address token, uint256 thresholdValue) = abi.decode(_data, (address, address, uint256));
        address owner = address(bytes20(_data[0:20]));
        address token = address(bytes20(_data[20:40]));
        bytes4 selector = bytes4(_data[40:44]);
        uint256 thresholdValue = uint256(bytes32(_data[44:76]));
        spendingLimitValidatorStorage[kernel][token] = SpendingLimitValidatorStorage(selector, owner, thresholdValue);

        emit ThresholdValueChanged(kernel, token, thresholdValue);
    }

    function disable(bytes calldata _data) external override {
        address kernel = msg.sender;
        address token = abi.decode(_data, (address));
        delete spendingLimitValidatorStorage[kernel][token];
        delete spendingLimitState[kernel][token];
        emit ThresholdValueChanged(kernel, token, type(uint256).max);
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
        bytes4 funcSig = bytes4(userOp.callData[0:4]);
        address token = address(bytes20(userOp.callData[4:24]));
        uint256 amount = uint256(bytes32(userOp.callData[24:56]));
        SpendingLimitValidatorStorage memory validatorStorage = spendingLimitValidatorStorage[userOp.sender][token];
        SpendingLimitState storage state = spendingLimitState[userOp.sender][token];

        bytes32 hash = ECDSA.toEthSignedMessageHash(userOpHash);
        if (!(SignatureChecker.isValidSignatureNow(validatorStorage.owner, hash, userOp.signature))) {
            return SIG_VALIDATION_FAILED;
        }
        require(funcSig == validatorStorage.selector, "SpendingLimitValidator: not supported selector");

        // first time transfer or current timestamp > end of day timestamp, activate end of day timestamp state
        if (state.eodTimestamp == 0 || block.timestamp > state.eodTimestamp) {
            state.eodTimestamp = block.timestamp + DAY_IN_SECONDS;

            if (block.timestamp > state.eodTimestamp) {
                state.spent = 0;
            }
        }
        require(
            validatorStorage.thresholdValue >= state.spent + amount,
            "SpendingLimitValidator: attemp to spend over daily limit"
        );

        state.spent += amount;
        return 0;
    }

    function validateSignature(bytes32, bytes calldata) external pure override returns (uint256) {
        revert("not implemented");
    }
}
