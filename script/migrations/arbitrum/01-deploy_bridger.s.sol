// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@kinto-core/bridger/Bridger.sol";

import {MigrationHelper} from "@kinto-core-script/utils/MigrationHelper.sol";
import {UUPSProxy} from "@kinto-core-test/helpers/UUPSProxy.sol";

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import {Constants} from "@kinto-core-script/migrations/arbitrum/const.sol";

contract DeployBridgerScript is Constants, Test, MigrationHelper {
    Bridger internal bridger;
    address internal impl;

    function setUp() public {}

    function broadcast(address) internal override {
        if (block.chainid != ARBITRUM_CHAINID) {
            console2.log("This script is meant to be run on the chain: %s", ARBITRUM_CHAINID);
            return;
        }
        address bridgerAddress = _getChainDeployment("Bridger", ARBITRUM_CHAINID);
        if (bridgerAddress != address(0)) {
            console2.log("Already deployed bridger", bridgerAddress);
            return;
        }

        // Set DAI to zero, as it has a normal `permit` on Arbitrum.
        // Set wstEth to zero, as staking is not supported on Arbitrum.
        // Set USDe and sUSDe to zero, as staking USDe is not supported on Arbitrum.
        impl = create2(
            "BridgerV1-impl",
            abi.encodePacked(
                type(Bridger).creationCode,
                abi.encode(EXCHANGE_PROXY, CURVE_USDM_POOL, USDC, WETH, address(0), address(0), address(0), address(0))
            )
        );
        console2.log("Bridger implementation deployed at", address(impl));
        // deploy proxy contract and point it to implementation
        address proxy =
            create2("Bridger", abi.encodePacked(type(UUPSProxy).creationCode, abi.encode(address(impl), "")));
        bridger = Bridger(payable(address(proxy)));
        console2.log("Bridger proxy deployed at ", address(bridger));
        // Initialize proxy
        bridger.initialize(SENDER_ACCOUNT);
    }

    function validate(address deployer) internal view override {
        // Checks
        assertEq(bridger.senderAccount(), SENDER_ACCOUNT, "Invalid Sender Account");
        assertEq(bridger.owner(), deployer, "Invalid Owner");
    }
}
