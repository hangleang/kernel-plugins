// from: https://github.com/eth-infinitism/trampoline/blob/webauthn/contracts/WebauthnAccount.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import { IKernelValidator, UserOperation } from "kernel/validator/IValidator.sol";
import { SIG_VALIDATION_FAILED } from "kernel/utils/KernelHelper.sol";

import { IEllipticCurve } from "../externals/IEllipticCurve.sol";
import { Base64 } from "../externals/Base64.sol";
import { BytesData } from "../lib/BytesData.sol";

struct WebAuthnAccountStorage {
    address ec;
    uint256[2] q;
    bytes authDataBuffer;
}

contract WebAuthnValidator is IKernelValidator {
    event WebAuthnChanges(address indexed kernel, address indexed ec, uint256[2] q, bytes authDataBuffer);
    event WebAuthnEnabled(address indexed kernel, bool indexed enabled);

    // uint256 private constant EC_OFFSET = 0;
    // uint256 private constant OWNER_TWO_OFFSET = 20;
    // uint256 private constant OWNER_TWO_ENDPOS = 40;

    mapping(address => WebAuthnAccountStorage) public webAuthnValidatorStorage;
    mapping(address => bool) public webAuthnValidatorEnabled;

    function enable(bytes calldata _data) external override {
        address _kernel = msg.sender;

        // check if kernel is never enable this validator before, require `_data` to not empty
        if (webAuthnValidatorStorage[_kernel].ec == address(0)) {
            require(BytesData.compareBytes(_data, bytes("")), "WebAuthn: missing bytes data");
        }

        // check if given bytes `_data` is not empty, change the account storage
        if (BytesData.compareBytes(_data, bytes("")) && _data.length > 84) {
            (address ec, uint256[2] memory q, bytes memory authDataBuffer) =
                abi.decode(_data, (address, uint256[2], bytes));
            webAuthnValidatorStorage[_kernel] = WebAuthnAccountStorage(ec, q, authDataBuffer);
            emit WebAuthnChanges(_kernel, ec, q, authDataBuffer);
        }

        webAuthnValidatorEnabled[_kernel] = true;
        emit WebAuthnEnabled(_kernel, true);
    }

    function disable(bytes calldata) external override {
        address _kernel = msg.sender;
        webAuthnValidatorEnabled[_kernel] = false;
        emit WebAuthnEnabled(_kernel, false);
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
        bytes32 requestId,
        bytes calldata signatureWithData,
        address sender
    )
        internal
        view
        returns (uint256)
    {
        require(webAuthnValidatorEnabled[sender], "WebAuthn: disabled");
        WebAuthnAccountStorage memory _accountStorage = webAuthnValidatorStorage[sender];
        (
            bytes memory signature,
            bytes memory clientDataJSON //, bytes memory authenticatorDataBytes
        ) = abi.decode(signatureWithData, (bytes, bytes));

        (uint256 r, uint256 s) = this._getRSValues(signature);

        string memory requestIdHex = BytesData.toHex(requestId);

        bytes memory base64RequestId = bytes(Base64.encode(requestIdHex));

        bytes memory base64RequestIdFromClientDataJSON = this._getRequestIdFromClientDataJSON(clientDataJSON);

        require(keccak256(base64RequestId) == keccak256(base64RequestIdFromClientDataJSON), "Request IDs do not match");

        bytes32 clientDataHash = sha256(clientDataJSON);

        bytes memory signatureBase = abi.encodePacked(_accountStorage.authDataBuffer, clientDataHash);

        bytes32 signatureBaseTohash = sha256(signatureBase);
        bool validSinature =
            IEllipticCurve(_accountStorage.ec).validateSignature(signatureBaseTohash, [r, s], _accountStorage.q);

        // require(validSinature);
        if (validSinature) return 0;
        return SIG_VALIDATION_FAILED;
    }

    function _getRSValues(bytes calldata signature) public pure returns (uint256 r, uint256 s) {
        r = uint256(bytes32(signature[0:32]));
        s = uint256(bytes32(signature[32:64]));
    }

    function _getRequestIdFromClientDataJSON(bytes calldata clientDataJSON) public pure returns (bytes calldata) {
        return clientDataJSON[36:124];
    }
}
