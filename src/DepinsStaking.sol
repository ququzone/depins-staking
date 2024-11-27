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
        uint64 freezenPeriod;
        uint64 stakingRate;
    }

    struct Bag {
        uint64 stakingType;
        uint64 stakingTime;
        uint64 stakingRate;
        uint64 withdrawTime;
        uint256 stakingAmount;
    }

    event StopStake();
    event StartStake();
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
        stakeable = true;
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
            _stakingPeriod > 0 && _stakingRate > 0 && _stakingRate < 1000000 && _stakingPeriod % 86400 == 0,
            "invalid params"
        );
        require(stakingType[_stakingType].stakingPeriod == 0, "type exists");

        stakingType[_stakingType] =
            StakingType({stakingPeriod: _stakingPeriod, freezenPeriod: _freezenPeriod, stakingRate: _stakingRate});
        emit NewStakingType(_stakingType, _stakingPeriod, _freezenPeriod, _stakingRate);
    }

    function removeStakingType(uint64 _stakingType) external onlyOwner {
        require(stakingType[_stakingType].stakingPeriod > 0, "type not exists");

        delete stakingType[_stakingType];
        emit RemoveStakingType(_stakingType);
    }

    function stake(uint64 _stakingType, uint256 _stakingAmount) external returns (uint256 tokenId_) {
        require(_stakingAmount > 0, "zero amount");
        require(stakeable, "stake stopped");

        StakingType memory _type = stakingType[_stakingType];
        require(_type.stakingPeriod > 0, "type not exists");

        depins.safeTransferFrom(msg.sender, address(this), _stakingAmount);
        tokenId_ = nextId;
        ++nextId;

        uint64 _now = uint64(block.timestamp) / 86400 * 86400;
        uint64 _withdrawTime = 0;
        if (_type.freezenPeriod > 0) {
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

        _bag.withdrawTime = uint64(block.timestamp) / 86400 * 86400;
        success_ = true;

        emit Unstake(msg.sender, _tokenId);
    }

    function withdraw(uint256 _tokenId) external returns (uint256 amount_) {
        address _owner = _requireOwned(_tokenId);
        Bag memory _bag = bags[_tokenId];
        require(_bag.withdrawTime > 0, "staking");

        uint256 _amount = _bag.stakingAmount;
        uint256 yield = ((_bag.withdrawTime - _bag.stakingTime) / 86400 * _bag.stakingRate) * _amount / 1000000;
        delete bags[_tokenId];
        _burn(_tokenId);
        depins.safeTransfer(_owner, amount_ + yield);
        emit Withdraw(_owner, _tokenId, _amount, yield);
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
}
