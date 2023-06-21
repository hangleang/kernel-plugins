// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.19;

// import { KernelFactory, EIP1967Proxy, IKernelValidator } from "kernel/factory/KernelFactory.sol";
// import { IEntryPoint } from "account-abstraction/interfaces/IEntryPoint.sol";

// import { TwoECDSAValidator } from "../validator/TwoECDSAValidator.sol";

// contract TwoECDSAKernelFactory {
//     KernelFactory public immutable singletonFactory;
//     TwoECDSAValidator public immutable validator;
//     IEntryPoint public immutable entryPoint;

//     constructor(KernelFactory _singletonFactory, TwoECDSAValidator _validator, IEntryPoint _entryPoint) {
//         singletonFactory = _singletonFactory;
//         validator = _validator;
//         entryPoint = _entryPoint;
//     }

//     function createAccount(
//         address _ownerOne,
//         address _ownerTwo,
//         uint256 _index
//     )
//         external
//         returns (EIP1967Proxy proxy)
//     {
//         bytes memory data = abi.encodePacked(_ownerOne, _ownerTwo);
//         proxy = singletonFactory.createAccount(validator, data, _index);
//     }

//     function getAddress(address _ownerOne, address _ownerTwo, uint256 _index) public view returns (address) {
//         bytes memory data = abi.encodePacked(_ownerOne, _ownerTwo);
//         return singletonFactory.getAccountAddress(validator, data, _index);
//     }
// }
