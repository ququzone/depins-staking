// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

contract DepinsStaking is OwnableUpgradeable, ERC721EnumerableUpgradeable {
    using SafeERC20 for IERC20;

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
    event EmergencyWithdraw(uint256 tokenId, uint256 amount);

    IERC20 public immutable depins;
    mapping(uint64 => StakingType) public stakingType;
    mapping(uint256 => Bag) public bags;

    constructor(address _depins) {
        _disableInitializers();
        depins = IERC20(_depins);
    }

    function initialize(string memory _name, string memory _symbol) external initializer {
        __Ownable_init(msg.sender);
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
    }

    function newStakingType(uint64 _stakingType, uint64 _stakingPeriod, uint64 _stakingRate) external onlyOwner {
        require(_stakingPeriod > 0 && _stakingRate > 0 && _stakingRate < 1000000, "invalid params");
        require(stakingType[_stakingType].stakingPeriod == 0, "type exists");

        stakingType[_stakingType] = StakingType({stakingPeriod: _stakingPeriod, stakingRate: _stakingRate});
        emit NewStakingType(_stakingType, _stakingPeriod, _stakingRate);
    }

    function removeStakingType(uint64 _stakingType) external onlyOwner {
        require(stakingType[_stakingType].stakingPeriod > 0, "type not exists");

        delete stakingType[_stakingType];
        emit RemoveStakingType(_stakingType);
    }

    function stake() external returns (uint256) {}

    function unstake(uint256 _tokenId) external returns (bool) {}

    function withdraw(uint256 _tokenId) external returns (uint256) {}

    function emergencyWithdraw(uint256 _tokenId) external returns (uint256) {
        require(ownerOf(_tokenId) == msg.sender, "invalid owner");

        uint256 _amount = bags[_tokenId].stakingAmount;
        delete bags[_tokenId];
        _burn(_tokenId);
        depins.safeTransfer(msg.sender, _amount);
        emit EmergencyWithdraw(_tokenId, _amount);
        return _amount;
    }

    function adminWithdraw() external onlyOwner {
        require(totalSupply() == 0, "exists staking");
        depins.safeTransfer(msg.sender, depins.balanceOf(address(this)));
    }
}
