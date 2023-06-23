// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "kernel/validator/IValidator.sol";
import { SIG_VALIDATION_FAILED } from "kernel/utils/KernelHelper.sol";

struct WhitelistsValidatorStorage {
    bool enabled;
    bytes4 selector;
    uint32 addressOffset;
    uint32 valueOffset;
}

/**
 * @title WhitelistsValidator
 * @author hangleang
 * @notice Not for production, just PoC
 */
contract WhitelistsValidator is IKernelValidator {
    event WhitelistAdded(address indexed kernel, address indexed target);
    event WhitelistRemoved(address indexed kernel, address indexed target);

    uint256 private constant WHITELIST_OFFSET = 14;

    mapping(address kernel => WhitelistsValidatorStorage validatorStorage) public whitelistValidatorStorage;

    mapping(address kernel => mapping(address target => bool)) public isWhitelist;

    function enable(bytes calldata _data) external override {
        address kernel = msg.sender;
        bytes4 selector = bytes4(_data[0:4]);
        uint32 addressOffset = uint32(bytes4(_data[4:8]));
        uint32 valueOffset = uint32(bytes4(_data[8:12]));
        uint16 count = uint16(bytes2(_data[12:WHITELIST_OFFSET]));
        address[] memory whitelists = abi.decode(_data[WHITELIST_OFFSET:WHITELIST_OFFSET + (count * 20)], (address[]));

        whitelistValidatorStorage[kernel] = WhitelistsValidatorStorage(true, selector, addressOffset, valueOffset);

        for (uint16 i = 0; i < count; i++) {
            isWhitelist[kernel][whitelists[i]] = true;
            emit WhitelistAdded(kernel, whitelists[i]);
        }
    }

    function disable(bytes calldata _data) external override {
        address kernel = msg.sender;
        uint16 count = uint16(bytes2(_data[0:WHITELIST_OFFSET]));
        address[] memory whitelists = abi.decode(_data[WHITELIST_OFFSET:WHITELIST_OFFSET + (count * 20)], (address[]));

        for (uint16 i = 0; i < count; i++) {
            isWhitelist[kernel][whitelists[i]] = false;
            emit WhitelistRemoved(kernel, whitelists[i]);
        }

        delete whitelistValidatorStorage[kernel];
    }

    function validateUserOp(UserOperation calldata userOp, bytes32, uint256) external view override returns (uint256) {
        WhitelistsValidatorStorage memory validatorStorage = whitelistValidatorStorage[userOp.sender];
        if (!validatorStorage.enabled) {
            return SIG_VALIDATION_FAILED;
        }
        require(
            bytes4(userOp.callData[0:4]) == validatorStorage.selector, "WhitelistsValidator: not supported selector"
        );

        address target =
            address(bytes20(userOp.callData[validatorStorage.addressOffset:validatorStorage.addressOffset + 20]));
        require(isWhitelist[userOp.sender][target], "WhitelistsValidator: not in whitelist");

        // can be check with value transfer to target address
        uint256 value =
            uint256(bytes32(userOp.callData[validatorStorage.valueOffset:validatorStorage.valueOffset + 32]));
        return 0;
    }

    function validateSignature(bytes32, bytes calldata) external pure override returns (uint256) {
        revert("not implemented");
    }
}
