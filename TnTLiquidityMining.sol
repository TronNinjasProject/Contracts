pragma solidity >=0.8.0;
// SPDX-License-Identifier: MIT

interface ITRC20 {
function transferFrom(address from, address to, uint256 value) external returns (bool); 
function transfer(address to, uint256 value) external returns (bool);
function balanceOf(address who) external view returns (uint256);
function totalSupply() external view returns (uint256);
function allowance(address owner, address spender) external view returns (uint256); 
function approve(address spender, uint256 value) external returns (bool);
function name() external view returns (string memory);
event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract lpStaking{
    using SafeMath for uint;
    struct Pool{
        ITRC20 token;
        uint staked;
        uint accTokensPerShare;
        uint lastReward;
        uint rewardPerSecond;
    }
    uint constant WEEK_IN_SECONDS = 604800;
    uint constant MONTH_IN_SECONDS = 2592000;
    Pool[] public pools;
    address admin;
    ITRC20 rewardToken;
    
    struct User{
        uint staked;
        uint rewardDebt;
    }
    mapping(uint => mapping(address => User)) public users;
    constructor(address tnt) {
        admin = msg.sender;
        rewardToken = ITRC20(tnt);
    }
    
    function addPool(ITRC20 _token, uint _rewardPerSec) public {
        require(msg.sender == admin);
        pools.push(
            Pool({
                token : _token,
                staked: 0,
                accTokensPerShare: 0,
                lastReward: block.timestamp,
                rewardPerSecond: _rewardPerSec
            })
        );
    }
    
    function updateRewardWeekly(uint8 _pid, uint _amount) public{
        require(msg.sender == admin);
        updatePool(_pid);
        pools[_pid].rewardPerSecond = _amount.div(WEEK_IN_SECONDS);
    }
    
    function updateRewardMonthly(uint8 _pid, uint _amount) public{
        require(msg.sender == admin);
        updatePool(_pid);
        pools[_pid].rewardPerSecond = _amount.div(MONTH_IN_SECONDS);
    }
    
    function updatePool(uint8 _pid) public{
        Pool storage pool = pools[_pid];
        if(pool.staked == 0){
            pool.lastReward = block.timestamp;
            return;
        }
        pool.accTokensPerShare = pool.accTokensPerShare.add(pool.rewardPerSecond.mul(block.timestamp-pool.lastReward).mul(1e12)).div(pool.staked);
        pool.lastReward = block.timestamp;
    }
    
    function depositTokens(uint8 _pid, uint _amount) public {
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        updatePool(_pid);
        if (user.staked > 0) {
            
            uint256 pending =
                user.staked.mul(pool.accTokensPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            rewardToken.transfer(msg.sender, pending);
        }
        
        require(pool.token.transferFrom(msg.sender, address(this), _amount));
        user.staked = user.staked.add(_amount);
        pool.staked = pool.staked.add(_amount);
        
        user.rewardDebt = (pool.accTokensPerShare.mul(user.staked)).div(1e12); 
        
    }
    
    function withdraw(uint8 _pid, uint256 _amount) public {
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        updatePool(_pid);
        require(user.staked >= _amount, "withdraw: not good");
        uint256 pending =
            user.staked.mul(pool.accTokensPerShare).div(1e12).sub(
                user.rewardDebt
            );
        rewardToken.transfer(msg.sender, pending);
        
        
        user.staked = user.staked.sub(_amount);
        user.rewardDebt = (pool.accTokensPerShare.mul(user.staked)).div(1e12);
        pool.staked = pool.staked.sub(_amount);
        pool.token.transfer(address(msg.sender), _amount);
    }
    function claim(uint8 _pid) public{
        updatePool(_pid);
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        uint pending =
            user.staked.mul(pool.accTokensPerShare).div(1e12).sub(
                user.rewardDebt
            );
        pool.lastReward = block.timestamp;
        rewardToken.transfer(msg.sender, pending);
        user.rewardDebt = (pool.accTokensPerShare.mul(user.staked)).div(1e12);
    }
    function claimable(uint _pid, address userAddress) public view returns(uint pending){
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][userAddress];
        if(pool.staked == 0){
            return 0;
        }
        uint tempAccTokens = pool.accTokensPerShare.add(pool.rewardPerSecond.mul(block.timestamp-pool.lastReward).mul(1e12)).div(pool.staked);
        pending =
            user.staked.mul(tempAccTokens).div(1e12).sub(
                user.rewardDebt
            );
    }
    function staked(uint _pid, address userAddress) public view returns(uint){
        User storage user = users[_pid][userAddress];
        return user.staked;
    }
    function viewPool(uint _pid) public view returns(Pool memory pool){
        return pools[_pid];
    }
    // function poolName(uint8 _pid) public view returns(string memory){
    //     return pools[_pid].token.name();
    // }
    function emergencyWithdraw(uint8 _pid) public {
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        pool.token.transfer(msg.sender, user.staked);
        user.staked = 0;
        user.rewardDebt = 0;
    }
    
}

//---------------------------SAFE MATH STARTS HERE ---------------------------
library SafeMath {
  function mul(uint a, uint b) internal pure  returns (uint) {
    uint c = a * b;
    require(a == 0 || c / a == b);
    return c;
  }
  function div(uint a, uint b) internal pure returns (uint) {
    require(b > 0);
    uint c = a / b;
    require(a == b * c + a % b);
    return c;
  }
  function sub(uint a, uint b) internal pure returns (uint) {
    require(b <= a);
    return a - b;
  }
  function add(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    require(c >= a);
    return c;
  }
  function max64(uint64 a, uint64 b) internal  pure returns (uint64) {
    return a >= b ? a : b;
  }
  function min64(uint64 a, uint64 b) internal  pure returns (uint64) {
    return a < b ? a : b;
  }
  function max256(uint256 a, uint256 b) internal  pure returns (uint256) {
    return a >= b ? a : b;
  }
  function min256(uint256 a, uint256 b) internal  pure returns (uint256) {
    return a < b ? a : b;
  }
}
