// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


contract staking{
    function addRewardsTRX() public payable{}
    function addRewardsTRC20(uint tokens) public {}
    function updateRewardPercentage(uint trxpercentage, uint tntpercentage) public{}

}

contract Token {
    function transferFrom(address from, address to, uint256 value) public returns (bool){}

    function transfer(address to, uint256 value) public returns (bool){}

    function balanceOf(address who) public view returns (uint256){}

    function burn(uint256 _value) public {}

    function decimals() public view returns(uint8){}
}




contract NinjaStore  {
    using SafeMath for uint;
    staking StakingContract;
    Token TNT;
    uint trxPercentage = 10;
    uint tntPercentage = 10;
	// Add mapping for store items
	mapping(uint => uint) StoreItemsTNT;
	mapping(uint => uint) StoreItemsTNTKeys;
	mapping(uint => uint) StoreItemsTRX;
	mapping(uint => uint) StoreItemsTRXKeys;
	
    address payable contractOwner;
	address admin;
    
    event saleMade(address purchaseAddress, uint item);
	
    constructor(address tokenaddr,address adminAddress) public{
        TNT = Token(tokenaddr);
        contractOwner = msg.sender;
		admin = adminAddress;
    }
	
	
    function init(address stakingAddress) public{
		require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
        StakingContract = staking(stakingAddress);
    }
	
	
    function buyStoreItemTNT(uint itemNumber) external{
		require(StoreItemsTNT[itemNumber]  > 0,'Item not found in store');
		require(TNT.transferFrom(msg.sender, address(StakingContract), (StoreItemsTNT[itemNumber].mul(tntPercentage)).div(100)));
        require(TNT.transferFrom(msg.sender, address(this), (StoreItemsTNT[itemNumber].mul(100-tntPercentage)).div(100)));
        StakingContract.addRewardsTRC20(StoreItemsTNT[itemNumber]); 
		emit saleMade(msg.sender,StoreItemsTNTKeys[StoreItemsTNT[itemNumber]]);
    }
	
	
	function buyStoreItemTRX(uint itemNumber) payable external {
		require(StoreItemsTRX[itemNumber]  > 0,'Item not found in store');
        require(msg.value == StoreItemsTRX[itemNumber],'TRX is not enough');
        StakingContract.addRewardsTRX.value(msg.value.mul(trxPercentage).div(100))();
		 emit saleMade(msg.sender,StoreItemsTRXKeys[StoreItemsTRX[itemNumber]]);
    }
	
	
    
	
	/// update methods 
	
	
	
    function updateStoreItemTNT(uint itemNumber, uint newPrice) public  { 
	  require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
	   StoreItemsTNT[itemNumber] = newPrice;
	   StoreItemsTNTKeys[newPrice] = itemNumber;
        
    }
	
	function updateStoreItemTRX(uint itemNumber, uint newPrice) public  { 
	  require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
	   StoreItemsTRX[itemNumber] = newPrice;
	    StoreItemsTRXKeys[newPrice] = itemNumber;
        
    }
	
	
    function updatePercentage(uint trxpercentage, uint tntpercentage) public{
	   require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
        StakingContract.updateRewardPercentage(trxpercentage, tntpercentage);
        trxPercentage = trxpercentage;
        tntPercentage = tntpercentage;
    }
	
	function updateAdmin(address newAdminAddress) public{
			require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
            admin = newAdminAddress;
    }
    
	//// read methods 
	
	function checkItemPriceTNT(uint itemNumber) public view returns(uint ) {
		require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
		require(StoreItemsTNT[itemNumber]  > 0,'Item not found in store');
    	  return StoreItemsTNT[itemNumber];
	}
	
	
	function checkItemPriceTRX(uint itemNumber) public view returns(uint  ) {
		require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
		require(StoreItemsTRX[itemNumber]  > 0,'Item not found in store');
    	return StoreItemsTRX[itemNumber];
	}
	
	//////////// widthdraw methods
	
	
	  function withdrawTRX() external{
       require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
        msg.sender.transfer(address(this).balance);
    }
    function withdrawTNT() external{
       require(msg.sender == admin || msg.sender == contractOwner,'Only admins can use this method');
	   
        TNT.transfer(msg.sender, TNT.balanceOf(address(this)));
    }
	
}

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
