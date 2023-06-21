// from: https://github.com/eth-infinitism/trampoline/blob/webauthn/contracts/WebauthnAccount.sol
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

library BytesData {
    function getRequestId(bytes calldata clientDataJSON)
        internal
        pure
        returns (bytes memory requestIdFromClientDataJSON)
    {
        return clientDataJSON[40:];
    }

    function compareBytes(bytes memory b1, bytes memory b2) internal pure returns (bool) {
        if (b1.length != b2.length) {
            return false;
        }
        for (uint256 i = 0; i < b1.length; i++) {
            if (b1[i] != b2[i]) {
                return false;
            }
        }
        return true;
    }

    function toHex(bytes32 data) internal pure returns (string memory) {
        return string(abi.encodePacked("0x", toHex16(bytes16(data)), toHex16(bytes16(data << 128))));
    }

    function toHex16(bytes16 data) private pure returns (bytes32 result) {
        result = (bytes32(data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000)
            | ((bytes32(data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64);
        result = (result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000)
            | ((result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32);
        result = (result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000)
            | ((result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16);
        result = (result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000)
            | ((result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8);
        result = ((result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4)
            | ((result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8);
        result = bytes32(
            0x3030303030303030303030303030303030303030303030303030303030303030 + uint256(result)
                + (
                    ((uint256(result) + 0x0606060606060606060606060606060606060606060606060606060606060606) >> 4)
                        & 0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F
                ) * 39
        );
    }
}