// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../../src/apps/KintoAppRegistry.sol";
import "../../src/wallet/KintoWallet.sol";
import {MigrationHelper} from "@kinto-core-script/utils/MigrationHelper.sol";
import "forge-std/console2.sol";

import "@kinto-core-test/helpers/ArrayHelpers.sol";

contract Script is MigrationHelper {
    using ArrayHelpers for *;

    function run() public override {
        super.run();

        KintoAppRegistry kintoAppRegistry = KintoAppRegistry(_getChainDeployment("KintoAppRegistry"));

        address socketApp = 0x3e9727470C66B1e77034590926CDe0242B5A3dCc;

        _handleOps(
            abi.encodeWithSelector(
                KintoAppRegistry.setSponsoredContracts.selector,
                socketApp,
                [_getChainDeployment("SOL")].toMemoryArray(),
                [true].toMemoryArray()
            ),
            address(_getChainDeployment("KintoAppRegistry"))
        );

        assertEq(
            kintoAppRegistry.isSponsored(socketApp, _getChainDeployment("SOL")), true
        );
    }
}

