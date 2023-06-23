// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { console } from "forge-std/console.sol";
import { BaseScript } from "./Base.s.sol";

import { TokenSpendingLimitActions } from "../src/executor/TokenSpendingLimitActions.sol";
import { SpendingLimitValidator } from "../src/validator/SpendingLimitValidator.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployTwoECDSAValidator is BaseScript {
    function run() public broadcaster {
        TokenSpendingLimitActions action = new TokenSpendingLimitActions();

        bytes memory bytecode = type(SpendingLimitValidator).creationCode;
        (bool success, bytes memory returnData) =
            DETERMINISTIC_CREATE2_FACTORY.call(abi.encodePacked(bytecode, abi.encode(action)));
        require(success, "Failed to deploy SpendingLimitValidator");
        address validator = address(bytes20(returnData));
        console.log("SpendingLimitValidator deployed at: %s", validator);
    }
}
