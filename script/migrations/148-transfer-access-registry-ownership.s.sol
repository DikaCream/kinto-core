// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AccessRegistry} from "@kinto-core/access/AccessRegistry.sol";
import {UUPSProxy} from "@kinto-core-test/helpers/UUPSProxy.sol";
import {AccessManager} from "@openzeppelin-5.0.1/contracts/access/manager/AccessManager.sol";
import {Ownable} from "@openzeppelin-5.0.1/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin-5.0.1/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {MigrationHelper} from "@kinto-core-script/utils/MigrationHelper.sol";

import "forge-std/console2.sol";

contract DeployScript is MigrationHelper {
    function run() public override {
        super.run();

        AccessManager accessManager = AccessManager(_getChainDeployment("AccessManager"));
        AccessRegistry accessRegistry = AccessRegistry(_getChainDeployment("AccessRegistry"));
        address safe = getMamoriSafeByChainId(block.chainid);
        console2.log('safe:', safe);

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = AccessRegistry.upgradeAll.selector;
        selectors[1] = UUPSUpgradeable.upgradeToAndCall.selector;
        selectors[2] = AccessRegistry.disallowWorkflow.selector;
        selectors[3] = AccessRegistry.allowWorkflow.selector;

        vm.startBroadcast(deployerPrivateKey);

        accessManager.setTargetFunctionRole(address(accessRegistry), selectors, UPGRADER_ROLE);

        accessManager.labelRole(UPGRADER_ROLE, "UPGRADER_ROLE");

        accessManager.grantRole(UPGRADER_ROLE, safe, ACCESS_REGISTRY_UPGRADE_DELAY);

        accessRegistry.transferOwnership(address(accessManager));

        vm.stopBroadcast();

        assertEq(accessRegistry.owner(), address(accessManager));

        (bool immediate, uint32 delay) = accessManager.canCall(safe, address(accessRegistry), AccessRegistry.upgradeAll.selector);
        assertFalse(immediate);
        assertEq(delay, ACCESS_REGISTRY_UPGRADE_DELAY);

        (bool isMember, uint32 currentDelay) = accessManager.hasRole(UPGRADER_ROLE, safe);
        assertTrue(isMember);
        assertEq(currentDelay, ACCESS_REGISTRY_UPGRADE_DELAY);
    }
}
