// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";

contract StakingCampaign {
   
    struct StackingInfo {
        uint seq;
        uint amount;
        uint reward;
        bool isPayout;
        uint unlockTime;
    }

    event Deposited (
        address indexed sender,
        uint seq,
        uint amount,
        uint256 timestamp
    );

    event Claimed (
        address indexed sender,
        uint seq,
        uint amount,
        uint reward,
        uint256 timestamp
    );

    address public owner;
    modifier onlyAdmin {
        require(msg.sender == owner, 'Caller is not owner');
        _;
    }

    // ERC20 token for staking campaign
    IERC20 public token;
    // campaign name
    string public name;
    // total day for staking (in second)
    uint public duration;
    // annual percentage rate
    uint public apr;
    // total cap for campaign, stop campaign if cap is reached
    uint public maxCap;
    // expired time of campaign, no more staking is accepted (in second)
    uint public expiredTime; 
    // min amount for one staking deposit
    uint public minTransactionAmount;
    // max amount for one staking deposit
    uint public maxTransactionAmount;
    // total amount already payout for staker (payout = staking amount + reward)
    uint public totalPayoutAmount;
    // total reward need for campaign
    uint public totalCampaignReward;
    // total staked amount
    uint public totalStakedAmount;
    //
    bool public isMaxCapReached = false;

    mapping(address => StackingInfo[]) internal stakingList;

    /**
     * 
     */
    constructor (IERC20 _token, string memory _campaignName, uint _expiredTime, 
                uint _maxCap, uint _maxTransactionAmount, uint _minTransactionAmount,
                uint _duration, uint _apr) {
        owner = msg.sender;
        token = _token;
        name = _campaignName;
        expiredTime = block.timestamp + _expiredTime;
        maxCap = _maxCap;
        maxTransactionAmount = _maxTransactionAmount;
        minTransactionAmount = _minTransactionAmount;
        duration = _duration;
        apr = _apr;
    }

    /**
     * Deposit amount of token to stack
     */
    function deposit(uint _amount, address _userAddr) external {
        require(totalStakedAmount + _amount <= maxCap, "Total cap is reached");
        require(_amount >= minTransactionAmount, "Staking amount is too small");
        require(_amount <= maxTransactionAmount, "Staking amount is too big");
        require(block.timestamp < expiredTime, "Campaign is over");

        token.transferFrom(_userAddr, address(this), _amount);
        uint unlockTime = block.timestamp + duration;
        uint seq = stakingList[_userAddr].length + 1;
        uint reward = _amount*apr*duration/(365*24*60*60*100);

        StackingInfo memory staking = StackingInfo(seq, _amount, reward, false, unlockTime);
        stakingList[_userAddr].push(staking);
       
        totalStakedAmount += _amount;
        totalCampaignReward += reward;

        isMaxCapReached = (totalStakedAmount == maxCap || totalStakedAmount + minTransactionAmount > maxCap);

        emit Deposited(_userAddr, seq, _amount, block.timestamp);
    }

    function claim(uint _seq, address _userAddr) public {
        StackingInfo[] memory userStakings = stakingList[_userAddr];
        require(_seq > 0 && userStakings.length >= _seq, "Invalid index");

        uint idx = _seq - 1;
        
        StackingInfo memory staking = userStakings[idx];

        require(!staking.isPayout, "Stake is already payout");
        require(staking.unlockTime < block.timestamp, "Staking is in lock period");
        
        uint payout = staking.amount + staking.reward;

        token.transfer(_userAddr, payout);
        totalPayoutAmount += payout;
        
        stakingList[_userAddr][idx].isPayout = true;
        
        emit Claimed(_userAddr, _seq, staking.amount, staking.reward, block.timestamp);
    }
    
    function claimRemainingReward(address _userAddr) public onlyAdmin {
        require(block.timestamp > expiredTime, "Campaign is not over yet");

        uint remainingPayoutAmount = totalStakedAmount + totalCampaignReward - totalPayoutAmount;
        uint balance = token.balanceOf(address(this));

        token.transfer(_userAddr, balance - remainingPayoutAmount);
    }

    function getClaimableRemainningReward() public view returns (uint) {
        if(block.timestamp < expiredTime) return 0;
        else {
            uint remainingPayoutAmount = totalStakedAmount + totalCampaignReward - totalPayoutAmount;
            uint balance = token.balanceOf(address(this));
            return balance - remainingPayoutAmount;
        }
    }
    
    function getStakings(address _staker) public view returns (uint[] memory _seqs, uint[] memory _amounts, uint[] memory _rewards, bool[] memory _isPayouts, uint[] memory _timestamps) {
        StackingInfo[] memory userStakings = stakingList[_staker];
        
        uint length = userStakings.length;
        
        uint256[] memory seqList = new uint256[](length);
        uint256[] memory amountList = new uint256[](length);
        uint256[] memory rewardList = new uint256[](length);
        bool[] memory isPayoutList = new bool[](length);
        uint256[] memory timeList = new uint256[](length);
        
        for(uint idx = 0; idx < length; idx++) {
            StackingInfo memory stackingInfo = userStakings[idx];
            
            seqList[idx] = stackingInfo.seq;
            amountList[idx] = stackingInfo.amount;
            rewardList[idx] = stackingInfo.reward;
            isPayoutList[idx] = stackingInfo.isPayout;
            timeList[idx] = stackingInfo.unlockTime;
        }
        
        return (seqList, amountList, rewardList, isPayoutList, timeList);
    }
    
    function getCampaignInfo() public view returns (
            IERC20 _token, string memory _campaignName, uint _expiredTime, 
            uint _maxCap, uint _maxTransactionAmount, uint _minTransactionAmount,
            uint _duration, uint _apr, uint _stakedAmount,uint _totalPayoutAmount) {

        return (token, name, expiredTime, maxCap, maxTransactionAmount, minTransactionAmount, duration, apr, totalStakedAmount, totalPayoutAmount);
    }

    function transferOwnership(address _newOwner) public onlyAdmin {
        owner = _newOwner;
    }
}
