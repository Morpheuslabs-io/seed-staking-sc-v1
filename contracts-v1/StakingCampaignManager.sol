// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./StakingCampaign.sol";
import "./EIP712MetaTransaction.sol";

contract StakingCampaignManager is EIP712MetaTransaction{

    string private constant DOMAIN_NAME = "morpheuslabs.io";
    string private constant DOMAIN_VERSION = "1";

    address public owner;
    modifier onlyAdmin {
        require(msgSender() == owner, 'StakingCampaignManager: Caller is not owner');
        _;
    }

    // Authorized list
    mapping(address => bool) public authorized;

    modifier isAuthorized() {
        require(
            msgSender() == owner || authorized[msgSender()] == true, 
            "StakingCampaignManager: unauthorized"
        );
        _;
    }

    bool public _authorizationEnabled;

    struct AddressBlockNum {
        address addr;
        uint256 blockNum;
    }
    AddressBlockNum[] public campaignAddressBlockNumList;

    constructor() EIP712Base(DOMAIN_NAME, DOMAIN_VERSION, block.chainid) {
        owner = msgSender();
        _authorizationEnabled = false;
    }

    function enableAuthorization() public onlyAdmin {
        _authorizationEnabled = true;
    }

    function disableAuthorization() public onlyAdmin {
        _authorizationEnabled = false;
    }

    function addAuthorized(address auth) public onlyAdmin {
        authorized[auth] = true;
    }

    function addAuthorizedBatch(address[] memory authList) public onlyAdmin {
        for (uint256 i = 0; i < authList.length; i++) {
            addAuthorized(authList[i]);
        }
    }

    function clearAuthorized(address auth) public onlyAdmin {
        authorized[auth] = false;
    }

    function clearAuthorizedBatch(address[] memory authList) public onlyAdmin {
        for (uint256 i = 0; i < authList.length; i++) {
            clearAuthorized(authList[i]);
        }
    }

    function checkAuthorized(address auth) public view returns (bool) {
        if (msgSender() == owner) {
            return true;
        } else {
            return authorized[auth];
        }
    }

    function getCampaignAddressBlockNumListCount() external view returns (uint256) {
        return campaignAddressBlockNumList.length;
    }

    function getCampaignAddressBlockNumAtIndex(uint256 _index) 
    external view returns (address, uint256) {
        return (
            campaignAddressBlockNumList[_index].addr,
            campaignAddressBlockNumList[_index].blockNum
        );
    }
   
    function deployCampaign (IERC20 _token, string memory _campaignName, uint _expiredTime, 
                uint _maxCap, uint _maxTransactionAmount, uint _minTransactionAmount,
                uint _duration, uint _apr) external onlyAdmin {

        StakingCampaign campaignContract = new StakingCampaign(
            _token, _campaignName, _expiredTime, 
            _maxCap, _maxTransactionAmount, _minTransactionAmount,
            _duration, _apr
        );

        AddressBlockNum memory addrBlockNum;
        addrBlockNum.addr = address(campaignContract);
        addrBlockNum.blockNum = block.number;
        campaignAddressBlockNumList.push(addrBlockNum);
    }

    /**
     * Deposit amount of token to stack
     */
    function deposit(uint _amount, address _campaignContractAddress) external {
        require(!_authorizationEnabled || checkAuthorized(msgSender()), "StakingCampaignManager: unauthorized deposit");
        StakingCampaign campaignContract = StakingCampaign(_campaignContractAddress);
        campaignContract.deposit(_amount, msgSender());
    }

    function claim(uint _seq, address _campaignContractAddress) external {
        StakingCampaign campaignContract = StakingCampaign(_campaignContractAddress);
        campaignContract.claim(_seq, msgSender());
    }
    
    function claimRemainingReward(address _campaignContractAddress) external onlyAdmin {
        StakingCampaign campaignContract = StakingCampaign(_campaignContractAddress);
        campaignContract.claimRemainingReward(msgSender());
    }

    function getClaimableRemainningReward(address _campaignContractAddress) external view returns (uint) {
        StakingCampaign campaignContract = StakingCampaign(_campaignContractAddress);
        return campaignContract.getClaimableRemainningReward();
    }
    
    function getStakings(address _staker, address _campaignContractAddress) 
        external view returns (
            uint[] memory _seqs, uint[] memory _amounts, uint[] memory _rewards, bool[] memory _isPayouts, uint[] memory _timestamps
        ) {
        StakingCampaign campaignContract = StakingCampaign(_campaignContractAddress);
        return campaignContract.getStakings(_staker);
    }
    
    function getCampaignInfo(address _campaignContractAddress) external view returns (
            IERC20 _token, string memory _campaignName, uint _expiredTime, 
            uint _maxCap, uint _maxTransactionAmount, uint _minTransactionAmount,
            uint _duration, uint _apr, uint _stakedAmount,uint _totalPayoutAmount) {

        StakingCampaign campaignContract = StakingCampaign(_campaignContractAddress);
        return campaignContract.getCampaignInfo();
    }
}
