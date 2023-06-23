// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { console } from "forge-std/console.sol";
import { BaseScript } from "./Base.s.sol";

import { GenericExecutor } from "../src/executor/GenericExecutor.sol";
import { WhitelistsValidator } from "../src/validator/WhitelistsValidator.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployWhitelistTarget is BaseScript {
    function run() public broadcaster {
        GenericExecutor executor = new GenericExecutor();

        bytes memory bytecode = type(WhitelistsValidator).creationCode;
        (bool success, bytes memory returnData) =
            DETERMINISTIC_CREATE2_FACTORY.call(abi.encodePacked(bytecode, abi.encode(executor)));
        require(success, "Failed to deploy WhitelistValidator");
        address validator = address(bytes20(returnData));
        console.log("WhitelistValidator deployed at: %s", validator);
    }
}
