// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@aa/core/EntryPoint.sol";

import "../../src/interfaces/IKintoEntryPoint.sol";

import "../../src/KintoID.sol";
import "../../src/apps/KintoAppRegistry.sol";
import "../../src/tokens/EngenCredits.sol";
import "../../src/paymasters/SponsorPaymaster.sol";
import "../../src/wallet/KintoWallet.sol";
import "../../src/wallet/KintoWalletFactory.sol";

import "../helpers/UUPSProxy.sol";
import "../helpers/KYCSignature.sol";
import {KintoWalletHarness} from "../harness/KintoWalletHarness.sol";
import {SponsorPaymasterHarness} from "../harness/SponsorPaymasterHarness.sol";

abstract contract AATestScaffolding is KYCSignature {
    IKintoEntryPoint _entryPoint;

    KintoAppRegistry _kintoAppRegistry;

    KintoID _implementation;
    KintoID _kintoIDv1;

    // Wallet & Factory
    KintoWalletFactory _walletFactory;
    KintoWallet _kintoWalletImpl;
    IKintoWallet _kintoWallet;

    EngenCredits _engenCredits;
    SponsorPaymaster _paymaster;

    // proxies
    UUPSProxy _proxy;
    UUPSProxy _proxyFactory;
    UUPSProxy _proxyPaymaster;
    UUPSProxy _proxyCredit;
    UUPSProxy _proxyRegistry;

    function deployAAScaffolding(address _owner, uint256 _ownerPk, address _kycProvider, address _recoverer) public {
        // Deploy Kinto ID
        deployKintoID(_owner, _kycProvider);

        EntryPoint entry = new EntryPoint{salt: 0}();
        _entryPoint = IKintoEntryPoint(address(entry));

        // Deploy wallet & wallet factory
        deployWalletFactory(_owner);

        // Deploy Kinto App
        deployAppRegistry(_owner);

        // Approve wallet's owner KYC
        approveKYC(_kycProvider, _owner, _ownerPk);

        // Deploy paymaster
        deployPaymaster(_owner);

        // Deploy Engen Credits
        deployEngenCredits(_owner);

        vm.prank(_owner);

        // deploy latest KintoWallet version through wallet factory and initialize it
        _kintoWallet = _walletFactory.createAccount(_owner, _recoverer, 0);

        // give some eth
        vm.deal(_owner, 1e20);
    }

    function fundSponsorForApp(address _contract) internal {
        // we add the deposit to the counter contract in the paymaster
        _paymaster.addDepositFor{value: 1e19}(address(_contract));
    }

    function deployKintoID(address _owner, address _kycProvider) public {
        vm.startPrank(_owner);
        // Deploy Kinto ID
        _implementation = new KintoID();

        // deploy _proxy contract and point it to _implementation
        _proxy = new UUPSProxy{salt: 0}(address(_implementation), "");

        // wrap in ABI to support easier calls
        _kintoIDv1 = KintoID(address(_proxy));

        // Initialize _proxy
        _kintoIDv1.initialize();
        _kintoIDv1.grantRole(_kintoIDv1.KYC_PROVIDER_ROLE(), _kycProvider);
        vm.stopPrank();
    }

    function deployWalletFactory(address _owner) public {
        vm.startPrank(_owner);

        // deploy wallet implementation (temporary because of loop dependency on app)
        _kintoWalletImpl = new KintoWallet{salt: 0}(_entryPoint, _kintoIDv1, KintoAppRegistry(address(0)));

        // deploy wallet factory implementation
        address _factoryImpl = address(new KintoWalletFactory{salt: 0}(_kintoWalletImpl));
        _proxyFactory = new UUPSProxy{salt: 0}(address(_factoryImpl), "");
        _walletFactory = KintoWalletFactory(address(_proxyFactory));

        // initialize wallet factory
        _walletFactory.initialize(_kintoIDv1);

        // set the wallet factory in the entry point
        _entryPoint.setWalletFactory(address(_walletFactory));

        vm.stopPrank();
    }

    function deployPaymaster(address _owner) public {
        vm.startPrank(_owner);

        // deploy the paymaster
        _paymaster = new SponsorPaymaster{salt: 0}(_entryPoint);

        // deploy _proxy contract and point it to _implementation
        _proxyPaymaster = new UUPSProxy{salt: 0}(address(_paymaster), "");

        // wrap in ABI to support easier calls
        _paymaster = SponsorPaymaster(address(_proxyPaymaster));

        // initialize proxy
        _paymaster.initialize(_owner);

        // Set the registry in the paymaster
        _paymaster.setAppRegistry(address(_kintoAppRegistry));

        vm.stopPrank();
    }

    function deployEngenCredits(address _owner) public {
        vm.startPrank(_owner);

        // deploy the engen credits
        _engenCredits = new EngenCredits{salt: 0}();

        // deploy _proxy contract and point it to _implementation
        _proxyCredit = new UUPSProxy{salt: 0}(address(_engenCredits), "");

        // wrap in ABI to support easier calls
        _engenCredits = EngenCredits(address(_proxyCredit));

        // initialize proxy
        _engenCredits.initialize();

        vm.stopPrank();
    }

    function deployAppRegistry(address _owner) public {
        vm.startPrank(_owner);

        // deploy the Kinto App registry
        _kintoAppRegistry = new KintoAppRegistry{salt: 0}(IKintoWalletFactory(_walletFactory));

        // deploy _proxy contract and point it to _implementation
        _proxyRegistry = new UUPSProxy{salt: 0}(address(_kintoAppRegistry), "");

        // wrap in ABI to support easier calls
        _kintoAppRegistry = KintoAppRegistry(address(_proxyRegistry));

        // initialize proxy
        _kintoAppRegistry.initialize();

        // Deploy a new wallet implementation an upgrade
        // Deploy wallet implementation
        _kintoWalletImpl = new KintoWallet{salt: 0}(_entryPoint, _kintoIDv1, _kintoAppRegistry);
        _walletFactory.upgradeAllWalletImplementations(_kintoWalletImpl);
        vm.stopPrank();
    }

    function approveKYC(address _kycProvider, address _account, uint256 _accountPk) public {
        vm.startPrank(_kycProvider);

        IKintoID.SignatureData memory sigdata =
            _auxCreateSignature(_kintoIDv1, _account, _account, _accountPk, block.timestamp + 1000);
        uint16[] memory traits = new uint16[](0);
        _kintoIDv1.mintIndividualKyc(sigdata, traits);

        vm.stopPrank();
    }

    function approveKYC(address _kycProvider, address _account, uint256 _accountPk, uint16[] memory traits) public {
        vm.startPrank(_kycProvider);

        IKintoID.SignatureData memory sigdata =
            _auxCreateSignature(_kintoIDv1, _account, _account, _accountPk, block.timestamp + 1000);
        _kintoIDv1.mintIndividualKyc(sigdata, traits);

        vm.stopPrank();
    }

    function revokeKYC(address _kycProvider, address _account, uint256 _accountPk) public {
        vm.startPrank(_kycProvider);

        IKintoID.SignatureData memory sigdata =
            _auxCreateSignature(_kintoIDv1, _account, _account, _accountPk, block.timestamp + 1000);
        _kintoIDv1.burnKYC(sigdata);

        vm.stopPrank();
    }

    // register app helpers
    // fixme: these should go through entrypoint

    function registerApp(address _owner, string memory name, address parentContract) public {
        address[] memory appContracts = new address[](0);
        uint256[4] memory appLimits = [
            _kintoAppRegistry.RATE_LIMIT_PERIOD(),
            _kintoAppRegistry.RATE_LIMIT_THRESHOLD(),
            _kintoAppRegistry.GAS_LIMIT_PERIOD(),
            _kintoAppRegistry.GAS_LIMIT_THRESHOLD()
        ];
        registerApp(_owner, name, parentContract, appContracts, appLimits);
    }

    function registerApp(address _owner, string memory name, address parentContract, uint256[4] memory appLimits)
        public
    {
        address[] memory appContracts = new address[](0);
        registerApp(_owner, name, parentContract, appContracts, appLimits);
    }

    function registerApp(address _owner, string memory name, address parentContract, address[] memory appContracts)
        public
    {
        uint256[4] memory appLimits = [
            _kintoAppRegistry.RATE_LIMIT_PERIOD(),
            _kintoAppRegistry.RATE_LIMIT_THRESHOLD(),
            _kintoAppRegistry.GAS_LIMIT_PERIOD(),
            _kintoAppRegistry.GAS_LIMIT_THRESHOLD()
        ];
        registerApp(_owner, name, parentContract, appContracts, appLimits);
    }

    // fixme: this should go through entrypoint
    function registerApp(
        address _owner,
        string memory name,
        address parentContract,
        address[] memory appContracts,
        uint256[4] memory appLimits
    ) public {
        vm.prank(_owner);
        _kintoAppRegistry.registerApp(
            name, parentContract, appContracts, [appLimits[0], appLimits[1], appLimits[2], appLimits[3]]
        );
    }

    function updateMetadata(address _owner, string memory name, address parentContract, address[] memory appContracts)
        public
    {
        uint256[4] memory appLimits = [
            _kintoAppRegistry.RATE_LIMIT_PERIOD(),
            _kintoAppRegistry.RATE_LIMIT_THRESHOLD(),
            _kintoAppRegistry.GAS_LIMIT_PERIOD(),
            _kintoAppRegistry.GAS_LIMIT_THRESHOLD()
        ];
        vm.prank(_owner);
        _kintoAppRegistry.updateMetadata(name, parentContract, appContracts, appLimits);
    }

    function updateMetadata(address _owner, string memory name, address parentContract, uint256[4] memory appLimits)
        public
    {
        address[] memory appContracts = new address[](0);
        vm.prank(_owner);
        _kintoAppRegistry.updateMetadata(name, parentContract, appContracts, appLimits);
    }

    function updateMetadata(
        address _owner,
        string memory name,
        address parentContract,
        uint256[4] memory appLimits,
        address[] memory appContracts
    ) public {
        vm.prank(_owner);
        _kintoAppRegistry.updateMetadata(name, parentContract, appContracts, appLimits);
    }

    function setSponsoredContracts(address _owner, address app, address[] memory contracts, bool[] memory sponsored)
        public
    {
        vm.prank(_owner);
        _kintoAppRegistry.setSponsoredContracts(app, contracts, sponsored);
    }

    function whitelistApp(address app) public {
        whitelistApp(app, true);
    }

    function whitelistApp(address app, bool whitelist) public {
        address[] memory targets = new address[](1);
        targets[0] = address(app);
        bool[] memory flags = new bool[](1);
        flags[0] = whitelist;
        vm.prank(address(_kintoWallet));
        _kintoWallet.whitelistApp(targets, flags);
    }

    function setAppKey(address app, address signer) public {
        vm.prank(address(_kintoWallet));
        _kintoWallet.setAppKey(app, signer);
    }

    function resetSigners(address[] memory newSigners, uint8 policy) public {
        vm.prank(address(_kintoWallet));
        _kintoWallet.resetSigners(newSigners, policy);
        assertEq(_kintoWallet.owners(0), newSigners[0]);
        assertEq(_kintoWallet.owners(1), newSigners[1]);
        assertEq(_kintoWallet.signerPolicy(), policy);
    }

    function setSignerPolicy(uint8 policy) public {
        vm.prank(address(_kintoWallet));
        _kintoWallet.setSignerPolicy(policy);
        assertEq(_kintoWallet.signerPolicy(), policy);
    }

    function useHarness() public {
        KintoWalletHarness _impl = new KintoWalletHarness(_entryPoint, _kintoIDv1, _kintoAppRegistry);
        vm.prank(_walletFactory.owner());
        _walletFactory.upgradeAllWalletImplementations(_impl);

        SponsorPaymasterHarness _paymasterImpl = new SponsorPaymasterHarness(_entryPoint);
        vm.prank(_paymaster.owner());
        _paymaster.upgradeTo(address(_paymasterImpl));
    }

    ////// helper methods to assert the revert reason on UserOperationRevertReason events ////

    // string reasons

    function assertRevertReasonEq(bytes memory _reason) public {
        bytes[] memory reasons = new bytes[](1);
        reasons[0] = _reason;
        _assertRevertReasonEq(reasons);
    }

    /// @dev if 2 or more UserOperationRevertReason events are emitted
    function assertRevertReasonEq(bytes[] memory _reasons) public {
        _assertRevertReasonEq(_reasons);
    }

    function _assertRevertReasonEq(bytes[] memory _reasons) internal {
        uint256 idx = 0;
        Vm.Log[] memory logs = vm.getRecordedLogs();

        for (uint256 i = 0; i < logs.length; i++) {
            // check if this is the correct event
            if (
                logs[i].topics[0] == keccak256("UserOperationRevertReason(bytes32,address,uint256,bytes)")
                    || logs[i].topics[0] == keccak256("PostOpRevertReason(bytes32,address,uint256,bytes)")
            ) {
                (, bytes memory revertReasonBytes) = abi.decode(logs[i].data, (uint256, bytes));

                // check that the revertReasonBytes is long enough (at least 4 bytes for the selector + additional data for the message)
                if (revertReasonBytes.length > 4) {
                    // remove the first 4 bytes (the function selector)
                    bytes memory errorBytes = new bytes(revertReasonBytes.length - 4);
                    for (uint256 j = 4; j < revertReasonBytes.length; j++) {
                        errorBytes[j - 4] = revertReasonBytes[j];
                    }
                    string memory decodedRevertReason = abi.decode(errorBytes, (string));
                    string[] memory prefixes = new string[](3);
                    prefixes[0] = "SP";
                    prefixes[1] = "KW";
                    prefixes[2] = "EC";

                    // clean revert reason & assert
                    string memory cleanRevertReason = _trimToPrefixAndRemoveTrailingNulls(decodedRevertReason, prefixes);
                    assertEq(cleanRevertReason, string(_reasons[idx]), "Revert reason does not match");

                    if (_reasons.length > 1) idx++; // if there's only one reason, we always use the same one
                } else {
                    revert("Revert reason bytes too short to decode");
                }
            }
        }
    }

    function _trimToPrefixAndRemoveTrailingNulls(string memory revertReason, string[] memory prefixes)
        internal
        pure
        returns (string memory)
    {
        bytes memory revertBytes = bytes(revertReason);
        uint256 meaningfulLength = revertBytes.length;
        if (meaningfulLength == 0) return revertReason;

        // find the actual end of the meaningful content
        for (uint256 i = revertBytes.length - 1; i >= 0; i--) {
            if (revertBytes[i] != 0) {
                meaningfulLength = i + 1;
                break;
            }
            if (i == 0) break; // avoid underflow
        }
        // trim until one of the prefixes
        for (uint256 j = 0; j < revertBytes.length; j++) {
            for (uint256 k = 0; k < prefixes.length; k++) {
                bytes memory prefixBytes = bytes(prefixes[k]);
                if (j + prefixBytes.length <= meaningfulLength) {
                    bool matched = true;
                    for (uint256 l = 0; l < prefixBytes.length; l++) {
                        if (revertBytes[j + l] != prefixBytes[l]) {
                            matched = false;
                            break;
                        }
                    }
                    if (matched) {
                        // create a new trimmed and cleaned string
                        bytes memory trimmedBytes = new bytes(meaningfulLength - j);
                        for (uint256 m = j; m < meaningfulLength; m++) {
                            trimmedBytes[m - j] = revertBytes[m];
                        }
                        return string(trimmedBytes);
                    }
                }
            }
        }

        // if no prefix is found or no meaningful content, return the original string
        return revertReason;
    }
}
