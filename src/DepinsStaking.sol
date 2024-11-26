// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

contract DepinsStaking is OwnableUpgradeable, ERC721EnumerableUpgradeable {
    struct StakingType {
        uint64 stakingPeriod;
        uint64 stakingRate;
    }

    struct Bag {
        uint64 stakingType;
        uint64 stakingTime;
        uint64 stakingRate;
        uint64 withdrawTime;
        uint256 stakingAmount;
    }

    event NewStakingType(uint64 stakingType, uint64 stakingPeriod, uint64 stakingRate);
    event RemoveStakingType(uint64 stakingType);

    address public immutable depins;
    mapping(uint64 => StakingType) public stakingType;
    mapping(uint256 => Bag) public bags;

    constructor(address _depins) {
        _disableInitializers();
        depins = _depins;
    }

    function initialize(string memory _name, string memory _symbol) external initializer {
        __Ownable_init(msg.sender);
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
    }
}
