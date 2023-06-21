// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19;

import { console } from "forge-std/console.sol";
import { BaseScript } from "./Base.s.sol";

import { TwoECDSAValidator } from "../src/validator/TwoECDSAValidator.sol";

// import { TwoECDSAKernelFactory } from "../src/factory/TwoECDSAKernelFactory.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract DeployTwoECDSAValidator is BaseScript {
    function run() public broadcaster {
        bytes memory bytecode = type(TwoECDSAValidator).creationCode;
        bool success;
        bytes memory returnData;
        (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(abi.encodePacked(bytecode));
        require(success, "Failed to deploy ECDSAValidator");
        address validator = address(bytes20(returnData));
        console.log("TwoECDSAValidator deployed at: %s", validator);

        // bytecode = type(TwoECDSAKernelFactory).creationCode;
        // (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(
        //     abi.encodePacked(bytecode, abi.encode(KERNEL_FACTORY), abi.encode(validator), abi.encode(ENTRYPOINT))
        // );
        // require(success, "Failed to deploy TwoECDSAKernelFactory");
        // address twoEcdsaFactory = address(bytes20(returnData));
        // console.log("TwoECDSAKernelFactory deployed at: %s", twoEcdsaFactory);
    }
}
