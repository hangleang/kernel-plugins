// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import { Exec } from "kernel/utils/Exec.sol";

contract GenericExecutor {
    function execute(address to, uint256 value, bytes calldata data) external {
        (bool success, bytes memory ret) = Exec.call(to, value, data);
        if (!success) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }
}
