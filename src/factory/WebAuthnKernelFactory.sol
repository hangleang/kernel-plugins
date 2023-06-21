// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// import { KernelFactory, EIP1967Proxy, IKernelValidator } from "kernel/factory/KernelFactory.sol";
// import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";

// import { WebAuthnValidator } from "../validator/WebAuthnValidator.sol";

contract WebAutnKernelFactory {
//     KernelFactory public immutable singletonFactory;
//     WebAuthnValidator public immutable validator;
//     IEntryPoint public immutable entryPoint;

//     constructor(KernelFactory _singletonFactory, WebAuthnValidator _validator, IEntryPoint _entryPoint) {
//         singletonFactory = _singletonFactory;
//         validator = _validator;
//         entryPoint = _entryPoint;
//     }

//     function createAccount(
//         address anEllipticCurve,
//         uint256[2] memory _q,
//         bytes memory authDataBuffer,
//         uint256 _index
//     )
//         external
//         returns (EIP1967Proxy proxy)
//     {
//         bytes memory data = abi.encode(anEllipticCurve, _q, authDataBuffer);
//         proxy = singletonFactory.createAccount(validator, data, _index);
//     }

//     function getAddress(
//         address anEllipticCurve,
//         uint256[2] memory _q,
//         bytes memory authDataBuffer,
//         uint256 _index
//     )
//         public
//         view
//         returns (address)
//     {
//         bytes memory data = abi.encode(anEllipticCurve, _q, authDataBuffer);
//         return singletonFactory.getAccountAddress(validator, data, _index);
//     }
}
