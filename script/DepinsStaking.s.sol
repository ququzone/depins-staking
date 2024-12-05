// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DepinsStaking} from "src/DepinsStaking.sol";
import {Depins} from "src/test/Depins.sol";

contract DeployVault is Script {
    address public depins;

    function setUp() external {
        depins = vm.envOr("DEPINS", address(0));
    }

    function run() external {
        vm.startBroadcast();

        if (depins == address(0)) {
            depins = address(new Depins());
            console.log("Depins deployed to: '%s'", depins);
        }

        DepinsStaking implementation = new DepinsStaking(depins);
        TransparentUpgradeableProxy staking = new TransparentUpgradeableProxy(
            address(implementation),
            msg.sender,
            abi.encodeCall(DepinsStaking.initialize, (61 days, "Depins Staking", "DST"))
        );

        vm.stopBroadcast();

        console.log("DepinsStaking deployed to: '%s'", address(staking));
    }
}
