pragma solidity >=0.5.0;
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

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function setApprovalForAll(address operator, bool _approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


contract FailSafe{
    address payable public admin;
    constructor() public{
        admin = msg.sender;
    }
    
    function FailSafeTrxRemove(uint amountInSun) external{
        require(msg.sender == admin, "Not admin");
        admin.transfer(amountInSun);
    }
    function FailSafeTRC10Remove(uint tokenID, uint amount) external{
        require(msg.sender == admin, "Not admin");
        admin.transferToken(amount, tokenID);
    }
    function FailSafeStopContract() external{
        require(msg.sender == admin, "Not admin");
        selfdestruct(admin);
    }
    function FailSafeTRC20Remove(address contractAddress, uint amountWithPrecision) external{
        require(msg.sender == admin, "Not admin");
        ITRC20(contractAddress).transfer(admin, amountWithPrecision);
    }
    function FailSafeTRC721Remove(address contractAddress, uint tokenID) external{
        require(msg.sender == admin, "Not admin");
        IERC721(contractAddress).transferFrom(address(this), admin, tokenID);
    }
}

contract lpStaking is FailSafe{
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
    ITRC20 rewardToken;
    struct User{
        uint staked;
        uint rewardDebt;
		uint256 totalPaidout;
    }
    mapping(uint => mapping(address => User)) public users;
    address payable admin;
    constructor(address tnt) public{
        admin = msg.sender;
        rewardToken = ITRC20(tnt);
    }
    
	
	event UserClaimed(address indexed user, uint indexed amount);
	
    function addPool(ITRC20 _token, uint _rewardPerSec) public {
        require(msg.sender == admin, "Not Admin");
        require(pools.length<255, "No more pools");
        pools.push(
            Pool({
                token : _token,
                staked: 0,
                accTokensPerShare: 0,
                lastReward: now,
                rewardPerSecond: _rewardPerSec
            })
        );
    }
    
    function updateRewardWeekly(uint _pid, uint _amount) public{
        require(msg.sender == admin, "Not Admin");
        updatePool(_pid);
        pools[_pid].rewardPerSecond = _amount.div(WEEK_IN_SECONDS);
    }
    
    function updateRewardMonthly(uint _pid, uint _amount) public{
        require(msg.sender == admin, "Not Admin");
        updatePool(_pid);
        pools[_pid].rewardPerSecond = _amount.div(MONTH_IN_SECONDS);
    }
    
    function updatePool(uint _pid) public{
        Pool storage pool = pools[_pid];
        if(pool.staked == 0){
            pool.lastReward = now;
            return;
        }
        pool.accTokensPerShare = pool.accTokensPerShare.add(
            (
                (pool.rewardPerSecond.mul(now-pool.lastReward)).mul(1e12)
            ).div(pool.staked)
        );
        pool.lastReward = now;
    }
    
    function accTokensPerShare(uint _pid) public view returns(uint){
        return pools[_pid].accTokensPerShare;
    }
    function rewardPerSecond(uint _pid) public view returns(uint){
        return pools[_pid].rewardPerSecond;
    }
    function lastReward(uint _pid) public view returns(uint){
        return pools[_pid].lastReward;
    }
    function poolstaked(uint _pid) public view returns(uint){
        return pools[_pid].staked;
    }
    function blocktimestamp() public view returns(uint){
        return now;
    }
    
    
    function depositTokens(uint _pid, uint _amount) public {
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        updatePool(_pid);
        require(pool.token.transferFrom(msg.sender, address(this), _amount), "Unable To transfer");
        if (user.staked > 0) {
            
            uint256 pending =
                (user.staked.mul(pool.accTokensPerShare)).div(1e12).sub(
                    user.rewardDebt
                );
            rewardToken.transfer(msg.sender, pending);
			user.totalPaidout = user.totalPaidout.add(pending);
        }
        user.staked = user.staked.add(_amount);
        pool.staked = pool.staked.add(_amount);
        
        user.rewardDebt = (pool.accTokensPerShare.mul(user.staked)).div(1e12); 
        
    }
    
    function withdraw(uint _pid, uint256 _amount) public returns(uint pending){
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        updatePool(_pid);
        require(user.staked >= _amount, "withdraw: not good");
        pending =
            (user.staked.mul(pool.accTokensPerShare)).div(1e12).sub(
                user.rewardDebt
            );
		rewardToken.transfer(msg.sender, pending);
        user.totalPaidout = user.totalPaidout.add(pending);
        emit UserClaimed(msg.sender, pending);
        user.staked = user.staked.sub(_amount);
        user.rewardDebt = (pool.accTokensPerShare.mul(user.staked)).div(1e12);
        pool.staked = pool.staked.sub(_amount);
        pool.token.transfer(address(msg.sender), _amount);
    }
    
    function claim(uint _pid) public returns(uint pending){
        updatePool(_pid);
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        pending =
            (user.staked.mul(pool.accTokensPerShare)).div(1e12).sub(
                user.rewardDebt
            );
        rewardToken.transfer(msg.sender, pending);
		 user.totalPaidout = user.totalPaidout.add(pending);
		 emit UserClaimed(msg.sender, pending);
        user.rewardDebt = (pool.accTokensPerShare.mul(user.staked)).div(1e12);
    }
    function claimable(uint _pid, address userAddress) public view returns(uint pending){
        Pool memory pool = pools[_pid];
        User memory user = users[_pid][userAddress];
        if(pools[_pid].staked == 0){
            return 0;
        }
        uint tempAccTokens = 
        pool.accTokensPerShare.add(
            (
                (pool.rewardPerSecond.mul(now-pool.lastReward)).mul(1e12)
            ).div(pool.staked)
        );
        pending = ((user.staked.mul(tempAccTokens)).div(1e12)).sub(user.rewardDebt);
    }
    function staked(uint _pid, address userAddress) public view returns(uint){
        User storage user = users[_pid][userAddress];
        return user.staked;
    }
	
	function totalUserPaidout(uint _pid, address userAddress) public view returns(uint){
        User storage user = users[_pid][userAddress];
        return user.totalPaidout;
    }
    function viewPool(uint _pid) public view returns(address, uint, uint, uint, uint){
        address tokenAddr = address(pools[_pid].token);
        uint stakedT = pools[_pid].staked;
        uint accTokensPerShareT = pools[_pid].accTokensPerShare;
        uint lastRewardT = pools[_pid].lastReward;
        uint rewardPerSecondT = pools[_pid].rewardPerSecond;
        return(tokenAddr, stakedT, accTokensPerShareT, lastRewardT, rewardPerSecondT);
    }
    function emergencyWithdraw(uint256 _pid) public {
        Pool storage pool = pools[_pid];
        User storage user = users[_pid][msg.sender];
        pool.token.transfer(address(msg.sender), user.staked);
        pool.staked = pool.staked.subsafe(user.staked);
        user.staked = 0;
        user.rewardDebt = 0;
    }
    function transferOwnership(address payable adminAddr) external{
        require(msg.sender == admin, "Not Admin");
        admin = adminAddr;
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
  function subsafe(uint a, uint b) internal pure returns (uint) {
    if(b>a){
        return 0;
    }
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
