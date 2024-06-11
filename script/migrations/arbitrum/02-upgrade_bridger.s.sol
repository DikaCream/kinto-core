// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@kinto-core/bridger/Bridger.sol";

import {MigrationHelper} from "@kinto-core-script/utils/MigrationHelper.sol";
import {ArtifactsReader} from "@kinto-core-test/helpers/ArtifactsReader.sol";
import {UUPSProxy} from "@kinto-core-test/helpers/UUPSProxy.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Constants} from "@kinto-core-script/migrations/arbitrum/const.sol";

contract UpgradeBridgerScript is Constants, Test, MigrationHelper {
    Bridger internal bridger;
    address internal newImpl;
    address internal bridgerAddress;

    function setUp() public {}

    function broadcast(address) internal override {
        bridgerAddress = _getChainDeployment("Bridger", ARBITRUM_CHAINID);
        if (bridgerAddress == address(0)) {
            console.log("Not deployed bridger", bridgerAddress);
            return;
        }

        // Deploy implementation
        newImpl = create2(
            "BridgerV2-impl",
            abi.encodePacked(
                type(Bridger).creationCode,
                abi.encode(EXCHANGE_PROXY, CURVE_USDM_POOL, USDC, WETH, address(0), address(0), address(0), address(0))
            )
        );
        bridger = Bridger(payable(bridgerAddress));
        bridger.upgradeTo(address(newImpl));
    }

    function validate(address deployer) internal view override {
        // Checks
        assertEq(bridger.senderAccount(), SENDER_ACCOUNT, "Invalid Sender Account");
        assertEq(bridger.owner(), deployer, "Invalid Owner");
        console.log("BridgerV2-impl at: %s", address(newImpl));
    }
}
