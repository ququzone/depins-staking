// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Depins} from "../src/test/Depins.sol";
import {DepinsStaking, Bag} from "../src/DepinsStaking.sol";

contract DepinsStakingTest is Test {
    Depins public depins;
    DepinsStaking public staking;

    address public alice = address(0xa);

    function setUp() public {
        depins = new Depins();
        staking = new DepinsStaking(address(depins));
        staking.initialize(61 days, "Depins Staking", "DST");
        staking.newStakingType(
            0, // fixed
            61 days,
            0,
            1370
        );
        staking.newStakingType(
            1, // flexible
            1 days,
            2 days, // freezen
            410
        );
    }

    function testFixedStaking() public {
        vm.warp(100 days + 100);
        uint256 start = block.timestamp;

        depins.mint(10000 ether);
        depins.transfer(address(staking), 10000 ether);

        vm.startPrank(alice);
        depins.mint(100 ether);

        depins.approve(address(staking), 10000 ether);

        staking.stake(0, 100 ether);
        Bag memory bag = staking.bag(0);
        assertEq(bag.stakingTime, 100 days);

        vm.warp(start + 1 days);
        vm.expectRevert("unstaked");
        staking.unstake(0);
        vm.expectRevert("staking");
        staking.withdraw(0);

        vm.warp(start + 3 days);
        assertEq(depins.balanceOf(alice), 0);
        vm.expectRevert("staking");
        staking.withdraw(0);
        assertEq(depins.balanceOf(alice), 0);

        vm.warp(start + 61 days);
        staking.withdraw(0);
        assertEq(depins.balanceOf(alice), 100 ether + 0.137 ether * 61);
    }

    function testFlexibleStaking() public {
        vm.warp(100 days + 100);
        uint256 start = block.timestamp;

        depins.mint(10000 ether);
        depins.transfer(address(staking), 10000 ether);

        vm.startPrank(alice);
        depins.mint(100 ether);

        depins.approve(address(staking), 10000 ether);
        vm.expectRevert("type not exists");
        staking.stake(2, 100 ether);
        Bag memory bag = staking.bag(0);
        assertEq(bag.stakingTime, 0);

        staking.stake(1, 100 ether);
        bag = staking.bag(0);
        assertEq(bag.stakingTime, 100 days);

        vm.warp(start + 1 days);
        staking.unstake(0);
        bag = staking.bag(0);
        assertEq(bag.withdrawTime, 103 days);

        vm.expectRevert("staking");
        staking.withdraw(0);

        vm.warp(start + 3 days);
        assertEq(depins.balanceOf(alice), 0);
        assertEq(staking.totalSupply(), 1);
        assertEq(staking.ownerOf(0), alice);
        staking.withdraw(0);
        assertEq(depins.balanceOf(alice), 100.041 ether);
        assertEq(staking.totalSupply(), 0);
    }
}
