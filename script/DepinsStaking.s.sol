// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {TransparentUpgradeableProxy} from
    "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {DepinsStaking} from "src/DepinsStaking.sol";
import {Depins} from "src/test/Depins.sol";

contract DeployVault is Script {
    function run() external {
        vm.startBroadcast();

        Depins depins = new Depins();
        DepinsStaking implementation = new DepinsStaking(address(depins));
        TransparentUpgradeableProxy staking = new TransparentUpgradeableProxy(
            address(implementation),
            msg.sender,
            abi.encodeCall(DepinsStaking.initialize, (61 days, "Depins Staking", "DST"))
        );

        vm.stopBroadcast();

        console.log("Depins deployed to: '%s'", address(depins));
        console.log("DepinsStaking deployed to: '%s'", address(staking));
    }
}
