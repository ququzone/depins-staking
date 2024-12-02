// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

struct StakingType {
    uint64 stakingPeriod;
    uint64 freezenPeriod;
    uint64 stakingRate;
    uint64 enable;
}

struct Bag {
    uint64 stakingType;
    uint64 stakingTime;
    uint64 stakingRate;
    uint64 withdrawTime;
    uint256 stakingAmount;
}

contract DepinsStaking is OwnableUpgradeable, ERC721EnumerableUpgradeable {
    using SafeERC20 for IERC20;

    uint64 constant DAY = 86400;

    event StopStake();
    event StartStake();
    event ChangeMaxStakePeriod(uint256 maxStakePeriod);
    event NewStakingType(uint64 stakingType, uint64 stakingPeriod, uint64 freezonPeriod, uint64 stakingRate);
    event RemoveStakingType(uint64 stakingType);
    event EmergencyWithdraw(uint256 tokenId, uint256 amount);
    event Stake(
        address indexed staker,
        uint256 tokenId,
        uint64 stakingType,
        uint64 stakingRate,
        uint64 withdrawTime,
        uint256 stakingAmount
    );
    event Unstake(address indexed operator, uint256 tokenId);
    event Withdraw(address indexed owner, uint256 tokenId, uint256 amount, uint256 yield);

    IERC20 public immutable depins;
    uint256 nextId;
    bool public stakeable;
    uint64 public maxStakePeriod;
    mapping(uint64 => StakingType) stakingTypes;
    mapping(uint256 => Bag) bags;

    constructor(address _depins) {
        depins = IERC20(_depins);
    }

    function initialize(uint64 _maxStakePeriod, string memory _name, string memory _symbol) external initializer {
        require(_maxStakePeriod > 0 && _maxStakePeriod % DAY == 0, "invalid period");
        __Ownable_init(msg.sender);
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        stakeable = true;
        maxStakePeriod = _maxStakePeriod;
    }

    function changeMaxStakePeriod(uint64 _maxStakePeriod) external onlyOwner {
        maxStakePeriod = _maxStakePeriod;
        emit ChangeMaxStakePeriod(_maxStakePeriod);
    }

    function stopStake() external onlyOwner {
        require(stakeable, "stopped");

        stakeable = false;
        emit StopStake();
    }

    function startStake() external onlyOwner {
        require(!stakeable, "started");

        stakeable = true;
        emit StartStake();
    }

    function newStakingType(uint64 _stakingType, uint64 _stakingPeriod, uint64 _freezenPeriod, uint64 _stakingRate)
        external
        onlyOwner
    {
        require(
            _stakingPeriod > 0 && _stakingRate > 0 && _stakingRate < 1000000 && _stakingPeriod % DAY == 0,
            "invalid params"
        );
        require(stakingTypes[_stakingType].stakingPeriod == 0, "type exists");

        stakingTypes[_stakingType] = StakingType({
            stakingPeriod: _stakingPeriod,
            freezenPeriod: _freezenPeriod,
            stakingRate: _stakingRate,
            enable: 1
        });
        emit NewStakingType(_stakingType, _stakingPeriod, _freezenPeriod, _stakingRate);
    }

    function removeStakingType(uint64 _stakingType) external onlyOwner {
        require(stakingTypes[_stakingType].enable != 0, "type not exists");

        stakingTypes[_stakingType].enable = 0;
        emit RemoveStakingType(_stakingType);
    }

    function stake(uint64 _stakingType, uint256 _stakingAmount) external returns (uint256 tokenId_) {
        require(_stakingAmount > 0, "zero amount");
        require(stakeable, "stake stopped");

        StakingType memory _type = stakingTypes[_stakingType];
        require(_type.enable == 1, "type not exists");

        depins.safeTransferFrom(msg.sender, address(this), _stakingAmount);
        tokenId_ = nextId;
        ++nextId;

        uint64 _now = uint64(block.timestamp) / DAY * DAY;
        uint64 _withdrawTime = 0;
        if (_type.freezenPeriod == 0) {
            _withdrawTime = _now + _type.stakingPeriod;
        }

        bags[tokenId_] = Bag({
            stakingType: _stakingType,
            stakingTime: _now,
            stakingRate: _type.stakingRate,
            withdrawTime: _withdrawTime,
            stakingAmount: _stakingAmount
        });
        _mint(msg.sender, tokenId_);

        emit Stake(msg.sender, tokenId_, _stakingType, _type.stakingRate, _withdrawTime, _stakingAmount);
    }

    function unstake(uint256 _tokenId) external returns (bool success_) {
        address _owner = _requireOwned(_tokenId);
        if (stakeable) {
            require(_owner == msg.sender, "only owner");
        }

        Bag storage _bag = bags[_tokenId];
        require(_bag.withdrawTime == 0, "unstaked");

        uint64 _withdrawTime = uint64(block.timestamp) / DAY * DAY;
        if (_withdrawTime - _bag.stakingTime > maxStakePeriod) {
            _withdrawTime = _bag.stakingTime + maxStakePeriod;
        }

        _bag.withdrawTime = _withdrawTime + stakingTypes[_bag.stakingType].freezenPeriod;
        success_ = true;

        emit Unstake(msg.sender, _tokenId);
    }

    function withdraw(uint256 _tokenId) external returns (uint256 amount_) {
        address _owner = _requireOwned(_tokenId);
        Bag memory _bag = bags[_tokenId];
        require(_bag.withdrawTime <= block.timestamp, "staking");

        uint256 _withdrawTime = _bag.withdrawTime - stakingTypes[_bag.stakingType].freezenPeriod;
        amount_ = _bag.stakingAmount;
        uint256 yield = uint256((_withdrawTime - _bag.stakingTime) / DAY * _bag.stakingRate) * amount_ / 1000000;
        delete bags[_tokenId];
        _burn(_tokenId);
        depins.safeTransfer(_owner, amount_ + yield);
        emit Withdraw(_owner, _tokenId, amount_, yield);
    }

    function emergencyWithdraw(uint256 _tokenId) external returns (uint256 amount_) {
        require(ownerOf(_tokenId) == msg.sender, "invalid owner");

        amount_ = bags[_tokenId].stakingAmount;
        delete bags[_tokenId];
        _burn(_tokenId);
        depins.safeTransfer(msg.sender, amount_);

        emit EmergencyWithdraw(_tokenId, amount_);
    }

    function adminWithdraw() external onlyOwner {
        require(totalSupply() == 0, "exists staking");
        depins.safeTransfer(msg.sender, depins.balanceOf(address(this)));
    }

    function bag(uint256 _tokenId) external view returns (Bag memory) {
        return bags[_tokenId];
    }

    function stakingType(uint64 _stakingType) external view returns (StakingType memory) {
        return stakingTypes[_stakingType];
    }
}
