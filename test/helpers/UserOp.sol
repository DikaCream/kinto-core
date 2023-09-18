// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import '../../src/wallet/KintoWallet.sol';
import '../../src/wallet/KintoWalletFactory.sol';

import '@aa/interfaces/IAccount.sol';
import '@aa/interfaces/INonceManager.sol';
import '@aa/interfaces/IEntryPoint.sol';
import '@aa/core/EntryPoint.sol';
import '@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol';
import {SignatureChecker} from '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

abstract contract UserOp is Test {
    using ECDSAUpgradeable for bytes32;

    function _packUserOp (UserOperation memory op, bool forSig) internal pure returns (bytes memory) {
      if (forSig) {
        return abi.encode(
          op.sender,
          op.nonce,
          keccak256(op.initCode),
          keccak256(op.callData),
          op.callGasLimit,
          op.verificationGasLimit,
          op.preVerificationGas,
          op.maxFeePerGas,
          op.maxPriorityFeePerGas,
          keccak256(op.paymasterAndData)
        );
      }
      return abi.encode(
        op.sender,
        op.nonce,
        op.initCode,
        op.callData,
        op.callGasLimit,
        op.verificationGasLimit,
        op.preVerificationGas,
        op.maxFeePerGas,
        op.maxPriorityFeePerGas,
        op.paymasterAndData,
        op.signature
      );
    }

    function _getUserOpHash (
      UserOperation memory op,
      IEntryPoint _entryPoint, uint256 chainID
    ) internal pure returns (bytes32) {
      bytes32 opHash = keccak256(_packUserOp(op, true));
      return keccak256(
        abi.encode(
          opHash,
          address(_entryPoint),
          chainID
        )
      );
    }

    function _signUserOp (
      UserOperation memory op,
      IEntryPoint _entryPoint,
      uint256 chainID,
      uint256[] calldata privateKeys
    ) internal pure returns (bytes memory) {
      bytes32 hash = _getUserOpHash(op, _entryPoint, chainID);
      hash = hash.toEthSignedMessageHash();

      bytes memory signature;
      for (uint i = 0; i < privateKeys.length; i++) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKeys[0], hash);
        if (i == 0) {
          signature = abi.encodePacked(r, s, v);
        } else {
          signature = abi.encodePacked(signature, r,s,v);
        }
      }

      return signature;
    }
    
    function createUserOperation(
      uint _chainID,
      address _account,
      uint nonce,
      uint256[] calldata _privateKeyOwners,
      address _targetContract,
      uint value,
      bytes calldata _bytesOp
    ) public view returns (UserOperation memory op) {
      return
        this.createUserOperationWithPaymaster(
          _chainID,
          _account,
          nonce,
          _privateKeyOwners,
          _targetContract,
          value,
          _bytesOp,
          address(0)
        );
    }

    function createUserOperationWithPaymaster(
      uint _chainID,
      address _account,
      uint nonce,
      uint256[] calldata _privateKeyOwners,
      address _targetContract,
      uint value,
      bytes calldata _bytesOp,
      address _paymaster
    ) public view returns (UserOperation memory op) {
      op = UserOperation({
        sender: _account,
        nonce: nonce,
        initCode: bytes(''),
        callData: abi.encodeCall(KintoWallet.execute, (_targetContract, value, _bytesOp)),
        callGasLimit: 4000000, // generate from call simulation
        verificationGasLimit: 150000, // verification gas. will add create2 cost (3200+200*length) if initCode exists
        preVerificationGas: 21000, // should also cover calldata cost.
        maxFeePerGas: 1, // grab from current gas
        maxPriorityFeePerGas: 1e9, // grab from current gas
        paymasterAndData: abi.encodePacked(_paymaster),
        signature: bytes('')
      });
      op.signature = _signUserOp(op, KintoWallet(payable(_account)).entryPoint(), _chainID, _privateKeyOwners);
      return op;
    }
}