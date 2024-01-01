// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import 'forge-std/Script.sol';
import '../../src/tokens/EngenCredits.sol';
import { Create2Helper } from '../../test/helpers/Create2Helper.sol';
import { ArtifactsReader } from '../../test/helpers/ArtifactsReader.sol';
import { UUPSProxy } from '../../test/helpers/UUPSProxy.sol';
import '@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import 'forge-std/console.sol';

contract KintoMigration1DeployScript is Create2Helper, ArtifactsReader {
    using ECDSAUpgradeable for bytes32;

    EngenCredits _implementation;
    EngenCredits _engenCredits;
    UUPSProxy _proxy;

    function setUp() public {}

    // solhint-disable code-complexity
    function run() public {

        console.log('RUNNING ON CHAIN WITH ID', vm.toString(block.chainid));
        // If not using ledger, replace
        // uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
        // vm.startBroadcast(deployerPrivateKey);
        console.log('Executing with address', msg.sender);
        vm.startBroadcast();
        address kintoIDAddress = _getChainDeployment('KintoID');
        if (kintoIDAddress == address(0)) {
            console.log('Need to execute main script first', kintoIDAddress);
            return;
        }
        address engenCreditsAddr = _getChainDeployment('EngenCredits');
        if (engenCreditsAddr != address(0)) {
            console.log('Already deployed credits', engenCreditsAddr);
            return;
        }

        // Engen Credits
        engenCreditsAddr = computeAddress(0,
            abi.encodePacked(type(EngenCredits).creationCode));
        if (isContract(engenCreditsAddr)) {
            _implementation = EngenCredits(engenCreditsAddr);
            console.log('Already deployed credits implementation at', address(engenCreditsAddr));
        } else {
            // Deploy Engen Credits implementation
            _implementation = new EngenCredits{ salt: 0 }();
            console.log('Engen Credits implementation deployed at', address(_implementation));
        }
        address engenCreditsProxyAddr = computeAddress(
            0, abi.encodePacked(type(UUPSProxy).creationCode,
            abi.encode(address(_implementation), '')));
        if (isContract(engenCreditsProxyAddr)) {
            _proxy = UUPSProxy(payable(engenCreditsProxyAddr));
            _engenCredits = EngenCredits(address(_proxy));
            console.log('Already deployed Engen Credits proxy at', address(engenCreditsProxyAddr));
        } else {
            // deploy proxy contract and point it to implementation
            _proxy = new UUPSProxy{salt: 0}(address(_implementation), '');
            // wrap in ABI to support easier calls
            _engenCredits = EngenCredits(address(_proxy));
            console.log('EngenCredits proxy deployed at ', address(_engenCredits));
            // Initialize proxy
            _engenCredits.initialize();
        }
        _engenCredits = EngenCredits(address(_proxy));
        vm.stopBroadcast();

        // Writes the addresses to a file
        console.log('Add these addresses to the artifacts file');
        console.log(string.concat('"EngenCredits-impl": "', vm.toString(address(_implementation)), '"'));
        console.log(string.concat('"EngenCredits": "', vm.toString(address(_engenCredits)), '"'));
    }
}
