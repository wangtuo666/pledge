// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBEP20 {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);
    function balanceOf(address account) external view  returns (uint256);
}
interface IPancakePair {
    function getReserves()
    external
    view
    returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);

}
interface IFeedContract {
    function calculateDailyLimit(uint256 period) external view returns (uint256);
    function getperiodStats(uint256 _perioddayss) external view returns (uint256,uint256,uint256,uint256);
    function A() external view returns(uint256);
    function A4() external view returns(uint256);
}
interface IExchange {
    function updateBalance(uint256 balance) external;
}
contract PledgeContract is Ownable {
    struct TokenInfo {
        string tokenName;
        address tokenContract;
        address tokenExchangeContract;
        bool status;
        uint256 totalAmount;
    }

    struct Order {
        uint256 orderNumber;
        address user;
        string tokenName;
        uint256 pledgeAmount;
        uint256 totalAmount;
        uint256 hasWithdraw;
        uint256 createTime;
        bool redemptionStatus;
    }

    struct UserOrders {
        address user;
        uint256[] orderNumbers;
    }

    struct TokenOrders {
        string tokenName;
        uint256[] orderNumbers;
    }

    struct Whitelist {
        address whitelistAddress;
        uint256 allocationRatio;
    }
    struct DayInfo{
        uint256 pledgeAmount;
        uint256 orderNum;
    }
    struct RoundInfo{
        uint256 pledgeAmount;
        uint256 orderNum;
        uint256 pledgeLimit;
        mapping(address => bool) pledgeUser;
    }

    address private DA1;
    address private DA2;
    address private feedAddress;

    address private wallet1;
    address private wallet2;
    address private wallet3;
    uint256 public wallet1Ratio = 10;
    uint256 public wallet2Ratio = 10;
    uint256 public wallet3Ratio = 10;
    address private C1;
    address private C2;
    address private F1;



    address private bweUsdtPairAddress;



    mapping(string => TokenInfo) private DA3;
    mapping(uint256 => Order) private DA4;
    mapping(address => UserOrders) private DA5;
    mapping(string => TokenOrders) private DA6;
    mapping(address => Whitelist) private DA7;
    bool private DA8;
    uint256 public DA9;
    uint256 private DA10;
    uint256 public tokenCount = 0;
    uint256 private prevOrderId = 0;
    string[] public tokenNames;

    mapping(uint256 => RoundInfo) private rounds;
    mapping(uint256 => DayInfo) private dayInfos;

    uint256 public constant A1 = 106;
    uint256 private constant A2 = 40;
    uint256 private constant B1 = 30;
    uint256 private constant B2 = 60;
    uint256 private constant B3 = 10;
    uint256 private constant D1 = 12666;
    uint256 private constant D2 = 7;
    uint256 private constant D3 = 106;
    uint256 private constant D4 = 525;
    uint256 private constant E1 = 1250 * 10 ** 18;
    uint256 private constant E2 = 20;
    uint256 public maxUsdt = 150 * 10000 * 10 ** 18;
    uint256 public minUsdt = 15 * 10000 * 10 ** 18;
    uint256 public totalOutPutBWE = 0;

    uint256 public prevWhaleBanance  = 0;

    uint256 public dayTimestamps = 1 days;
    constructor(address _usdtAddress, address _bweAddress,address _bweUsdtPairAddress) {
        DA1 = _usdtAddress;
        DA2 = _bweAddress;
        bweUsdtPairAddress = _bweUsdtPairAddress;
        DA8 = false;
        DA9 = block.timestamp;
        DA10 = 1;
    }


    function updateMaxMinUsdt(uint256 _max,uint256 _min) public onlyOwner{
        maxUsdt = _max;
        minUsdt = _min;
    }
    function getWhaleAmount() public view returns(uint256){
        IBEP20 bweToken = IBEP20(DA2);
        return bweToken.balanceOf(feedAddress);
    }
    function updateWallet(address _wallet1,address _wallet2,address _wallet3,uint256 _ratio1,uint256 _ratio2,uint256 _ratio3) external onlyOwner{
        wallet1 = _wallet1;
        wallet2 = _wallet2;
        wallet3 = _wallet3;
        wallet1Ratio = _ratio1;
        wallet2Ratio = _ratio2;
        wallet3Ratio = _ratio3;
    }
    function updateCAddress(address _C1,address _C2,address _F1,address _feedAddress) external onlyOwner{
        C1 = _C1;
        C2 = _C2;
        F1 = _F1;
        feedAddress = _feedAddress;
    }

    function transferBWEtoWallet() public {
        IBEP20 bweToken = IBEP20(DA2);
        uint256 feedAmount = getWhaleAmount();
        if(feedAmount > prevWhaleBanance){
            bweToken.transfer(wallet1,(feedAmount-prevWhaleBanance) * wallet1Ratio / 100);
            bweToken.transfer(wallet2,(feedAmount-prevWhaleBanance) * wallet2Ratio / 100);
            bweToken.transfer(wallet3,(feedAmount-prevWhaleBanance) * wallet3Ratio / 100);
            if(wallet1Ratio != 0 && wallet2Ratio != 0 && wallet3Ratio != 0){
                IExchange bweExchange  = IExchange(C1);
                IExchange nftExchange = IExchange(C2);
                bweToken.transfer(C1,(feedAmount-prevWhaleBanance) * 10 / 100);
                bweExchange.updateBalance((feedAmount-prevWhaleBanance) * 10 / 100);
                bweToken.transfer(C2,(feedAmount - prevWhaleBanance) * 10 / 100);
                nftExchange.updateBalance((feedAmount - prevWhaleBanance) * 10 / 100);
                prevWhaleBanance = feedAmount;
            }
        }
    }

    function setContractSwitch(bool _status) external onlyOwner {
        DA8 = _status;
        DA9 = block.timestamp;
    }

    function addTokenToList(
        string memory _tokenName,
        address _tokenContract,
        address _tokenExchangeContract
    ) external onlyOwner {
        require(!DA3[_tokenName].status, "Token name already exists");
        require(
            DA3[_tokenName].tokenContract != _tokenContract,
            "Token contract already exists"
        );
        require(
            DA3[_tokenName].tokenExchangeContract != _tokenExchangeContract,
            "Token exchange contract already exists"
        );

        DA3[_tokenName] = TokenInfo({
            tokenName: _tokenName,
            tokenContract: _tokenContract,
            tokenExchangeContract: _tokenExchangeContract,
            totalAmount: 0,
            status: true
        });
        tokenNames.push(_tokenName);
        tokenCount=tokenCount+1;
    }

    function setTokenStatus(
        string memory _tokenName,
        bool _status
    ) external onlyOwner {
        require(
            DA3[_tokenName].status != _status,
            "Token status is already set to the desired value"
        );
        DA3[_tokenName].status = _status;
    }

    function removeTokenFromList(string memory _tokenName) external onlyOwner {
        delete DA3[_tokenName];
        for (uint256 i = 0; i < tokenNames.length; i++) {
            if (keccak256(abi.encodePacked(tokenNames[i])) == keccak256(abi.encodePacked(_tokenName))) {
                tokenNames[i] = tokenNames[tokenNames.length - 1];
                tokenNames.pop();
                break;
            }
        }
        tokenCount=tokenCount-1;
    }

    function getCurrentPeriod() public view returns (uint256) {
        return (block.timestamp - DA9)/(10 * dayTimestamps) + 1;
    }
    function setPeriod() public returns (uint256){
        if(block.timestamp > (DA9 + 10 * dayTimestamps * DA10)){
            uint256 timeSinceSwitch = block.timestamp - DA9;
            DA10 = (timeSinceSwitch / (10 * dayTimestamps)) + 1;
        }
        return DA10;
    }




    function getPledgeAmountForCurrentPeriod() public view returns (uint256) {
        uint256 currentPeriod = getCurrentPeriod();
        return rounds[currentPeriod].pledgeLimit;
    }
    function getPledgeAmountForPeroid(uint256 _period) public view returns(uint256){
        return rounds[_period].pledgeLimit ;
    }
    function setPledgeAmountForPeroid(uint256 _period,uint256 _limit) public onlyOwner{
        rounds[_period].pledgeLimit = _limit * 10 ** 18;
    }

    function addToWhitelist(
        address _whitelistAddress,
        uint256 _allocationRatio
    ) external onlyOwner {
        DA7[_whitelistAddress] = Whitelist({
            whitelistAddress: _whitelistAddress,
            allocationRatio: _allocationRatio
        });
    }

    function removeFromWhitelist(address _whitelistAddress) external onlyOwner {
        delete DA7[_whitelistAddress];
    }

    function getExchangeRateBEP20ToUSDT(
        string memory _tokenName
    ) public view returns (uint112,uint112) {
        require(DA3[_tokenName].status,"not support this token ");
        address exchangeContract = DA3[_tokenName].tokenExchangeContract;
        IPancakePair pancakePair = IPancakePair(exchangeContract);
        (uint112 reserve0,uint112 reserve1,) = pancakePair.getReserves();
        address token0Address = pancakePair.token0();
        address tokenAddress = DA3[_tokenName].tokenContract;
        if(token0Address == tokenAddress){
            return (reserve0,reserve1);
        }
        return (reserve1,reserve0);
    }

    function getExchangeRateBEP20ToBWE() public view returns (uint112,uint112) {
        IPancakePair pancakePair = IPancakePair(bweUsdtPairAddress);
        (uint112 reserve0,uint112 reserve1,) = pancakePair.getReserves();
        address token0Address = pancakePair.token0();
        if(token0Address == DA2){
            return (reserve0,reserve1);
        }
        return (reserve1,reserve0);
    }

    function calculatePledge(
        string memory _tokenName,
        uint256 _pledgeAmount
    ) public view returns (uint256) {
        (uint256 t,uint256 u1) = getExchangeRateBEP20ToUSDT(_tokenName);
        uint256 usdt1 = _pledgeAmount * u1 / t;
        (uint256 b,uint256 u2 ) = getExchangeRateBEP20ToBWE();
        uint256 bweAmount = usdt1 * b / u2;
        return bweAmount;
    }

    function calculateMaxPledgeAmountFromBWE(string memory _tokenName) public view returns(uint256){
        uint256 maxPledge = getPledgeAmountForCurrentPeriod() / E2;
        (uint256 b,uint256 u2 ) = getExchangeRateBEP20ToBWE();
        uint256 usdtNum =maxPledge * u2 / b;
        if(usdtNum > maxUsdt) usdtNum = maxUsdt;
        (uint256 t,uint256 u1) = getExchangeRateBEP20ToUSDT(_tokenName);
        return usdtNum * t / u1;
    }
    function calculateMinPledgeAmountFromBWE(string memory _tokenName) public view returns(uint256){
        uint256 maxPledge = getPledgeAmountForCurrentPeriod()  / 100;
        (uint256 b,uint256 u2 ) = getExchangeRateBEP20ToBWE();
        uint256 usdtNum =maxPledge * u2 / b;
        if(usdtNum > minUsdt) usdtNum = minUsdt;

        (uint256 t,uint256 u1) = getExchangeRateBEP20ToUSDT(_tokenName);
        return usdtNum * t / u1;
    }
    function getTokenInfo(string memory _tokenName) public view returns(TokenInfo memory){
        return DA3[_tokenName];
    }

    function hasPledge() public view returns(bool){
        return rounds[DA10].pledgeUser[msg.sender];
    }

    function createPledgeOrder(
        string memory _tokenName,
        uint256 _pledgeAmount
    ) external {
        require(DA8,"contract is not active");
        setPeriod();
        require(!rounds[DA10].pledgeUser[msg.sender],"one period only can pledge one time");

        uint256 currentPeriodPledgeAmount = getPledgeAmountForCurrentPeriod();
        uint256 allPleggeAmount = rounds[DA10].pledgeAmount;
        uint256 bweAmount = calculatePledge(_tokenName,_pledgeAmount);
        uint256 maxToken = calculateMaxPledgeAmountFromBWE(_tokenName);
        uint256 minToken = calculateMinPledgeAmountFromBWE(_tokenName);
        require(
            allPleggeAmount + bweAmount <=
            currentPeriodPledgeAmount,
            "Pledge amount exceeds current period limit"
        );
        require(
            minToken <= _pledgeAmount && _pledgeAmount <= maxToken,
            "Pledge amount is not within the allowed range"
        );
        require(DA3[_tokenName].status, "Token is not allowed for pledging");

        IBEP20(DA3[_tokenName].tokenContract).transferFrom(msg.sender,address(this),_pledgeAmount);
        DA3[_tokenName].totalAmount += _pledgeAmount;
        totalOutPutBWE += (bweAmount * A1) / 100;
        prevOrderId += 1;
        DA4[prevOrderId] = Order({
            orderNumber: prevOrderId,
            user: msg.sender,
            tokenName: _tokenName,
            pledgeAmount: _pledgeAmount,
            totalAmount: (bweAmount * A1) / 100,
            hasWithdraw : 0,
            createTime: block.timestamp,
            redemptionStatus: false
        });

        DA5[msg.sender].orderNumbers.push(prevOrderId);
        DA6[_tokenName].orderNumbers.push(prevOrderId);
        rounds[DA10].pledgeAmount += bweAmount;
        rounds[DA10].orderNum += 1;
        rounds[DA10].pledgeUser[msg.sender] = true;
    }

    function createBNBPledgeOrder(
        string memory _tokenName,
        uint256 _pledgeAmount
    ) external payable {
        require(DA8,"contract is not active");

        setPeriod();
        require(!rounds[DA10].pledgeUser[msg.sender],"one period only can pledge one time");

        require(msg.value == _pledgeAmount,"pledge amount is not equale BNB send");
        uint256 currentPeriodPledgeAmount = getPledgeAmountForCurrentPeriod();
        uint256 allPleggeAmount = rounds[DA10].pledgeAmount;
        uint256 bweAmount = calculatePledge(_tokenName,_pledgeAmount);

        uint256 maxToken = calculateMaxPledgeAmountFromBWE(_tokenName);
        uint256 minToken = calculateMinPledgeAmountFromBWE(_tokenName);
        require(
            allPleggeAmount + bweAmount <=
            currentPeriodPledgeAmount,
            "Pledge amount exceeds current period limit"
        );
        require(
            minToken <= _pledgeAmount && _pledgeAmount <= maxToken,
            "Pledge amount is not within the allowed range"
        );
        require(DA3[_tokenName].status, "Token is not allowed for pledging");


        DA3[_tokenName].totalAmount += _pledgeAmount;
        totalOutPutBWE += (bweAmount * A1) / 100;
        prevOrderId += 1;
        DA4[prevOrderId] = Order({
            orderNumber: prevOrderId,
            user: msg.sender,
            tokenName: _tokenName,
            pledgeAmount: _pledgeAmount,
            totalAmount: (bweAmount * A1) / 100,
            hasWithdraw : 0,
            createTime: block.timestamp,
            redemptionStatus: false
        });

        DA5[msg.sender].orderNumbers.push(prevOrderId);

        DA6[_tokenName].orderNumbers.push(prevOrderId);
        rounds[DA10].pledgeAmount += bweAmount;
        rounds[DA10].orderNum += 1;
        rounds[DA10].pledgeUser[msg.sender] = true;

    }




    function allPledgeBwe() public  view returns(uint256){
        return rounds[DA10].pledgeAmount;
    }

    function withdraw(uint256 _orderNumber) external {
        Order storage order = DA4[_orderNumber];
        require(!order.redemptionStatus,"the order has been redeemed");

        uint256 orderCreationTimestamp = order.createTime;
        uint256 totalAmount = order.totalAmount;
        uint256 hoursSinceCreation = (block.timestamp - orderCreationTimestamp) * 4 / dayTimestamps  ;
        if(hoursSinceCreation > 40) hoursSinceCreation = 40;
        uint256 allCanWithdraw = totalAmount * hoursSinceCreation  / A2;
        uint256 amountToWithdraw = allCanWithdraw - order.hasWithdraw;
        require(amountToWithdraw > 0,"current time has no token to withdraw");
        IBEP20 bweToken = IBEP20(DA2);
        require(bweToken.balanceOf(address(this))>=amountToWithdraw,"contract bwe balance not enough");

        order.hasWithdraw = allCanWithdraw;

        totalOutPutBWE -= amountToWithdraw;

        require(
            bweToken.transfer(DA4[_orderNumber].user, amountToWithdraw),
            "Token transfer failed"
        );
    }

    function calcuWithdrawAmount(uint256 _orderNumber) public view returns(uint256,uint256){

        Order memory order = DA4[_orderNumber];
        if(order.redemptionStatus){
            return (0,block.timestamp);
        }

        uint256 orderCreationTimestamp = order.createTime;
        uint256 totalAmount = order.totalAmount;
        uint256 hoursSinceCreation = (block.timestamp - orderCreationTimestamp) * 4 / dayTimestamps;
        if(hoursSinceCreation > 40) hoursSinceCreation = 40;
        uint256 allCanWithdraw = totalAmount * hoursSinceCreation  / A2;
        uint256 amountToWithdraw = allCanWithdraw - order.hasWithdraw;
        uint256 nextTime = order.createTime + (hoursSinceCreation + 1 ) * 1 hours;

        return (amountToWithdraw,nextTime);
    }





    function calculateRedemption(
        uint256 _orderNumber
    ) public view returns (uint256) {
        uint256 orderCreationTimestamp = DA4[_orderNumber].createTime;
        uint256 totalAmount = DA4[_orderNumber].totalAmount;
        uint256 hasWithdraw = DA4[_orderNumber].hasWithdraw;
        uint256 daysSinceCreation = (block.timestamp - orderCreationTimestamp) / dayTimestamps;

        if (daysSinceCreation < 5) {
            return hasWithdraw + totalAmount *B1 /100;
        } else if (daysSinceCreation >= 5 && daysSinceCreation < 10) {
            return hasWithdraw + totalAmount * B1 /100;
        } else if (daysSinceCreation >= 10 && daysSinceCreation < 6 * 365) {
            return totalAmount * B3;
        } else {
            return 0;
        }
    }

    function redeem(uint256 _orderNumber) external {
        require(!DA4[_orderNumber].redemptionStatus,"the order has redeem");

        uint256 redemptionValue = calculateRedemption(_orderNumber);
        require(redemptionValue > 0, "Redemption is not possible");

        IBEP20 bweToken = IBEP20(DA2);
        require(
            bweToken.transferFrom(msg.sender, address(this), redemptionValue),
            "Token transfer failed"
        );
        totalOutPutBWE -= redemptionValue;

        uint256 _redemptionAmount = DA4[_orderNumber].pledgeAmount;
        DA3[DA4[_orderNumber].tokenName].totalAmount -= _redemptionAmount;
        DA4[_orderNumber].redemptionStatus = true;

        if(compareStrings(DA4[_orderNumber].tokenName, "BNB")){
            require(address(this).balance >= _redemptionAmount, "Insufficient balance.");
            (bool success,) = msg.sender.call{value: _redemptionAmount}("");
            require(success, "Transfer failed.");
        }else{
            IBEP20 stakedToken = IBEP20(
                DA3[DA4[_orderNumber].tokenName].tokenContract
            );

            require(
                stakedToken.transfer(msg.sender, _redemptionAmount),
                "Token transfer failed"
            );
        }

    }

    function isWhitelisted() public view returns (bool) {
        return DA7[msg.sender].whitelistAddress != address(0);
    }

    function withdrawBWE() external {
        require(isWhitelisted(), "Caller is not in the whitelist");
        require(block.timestamp >= DA9 + 6 * 365 days, "Contract has not reached 6 years yet");

        for (uint256 i = 0; i < tokenCount; i++) {
            if(compareStrings(tokenNames[i],"BNB")){
                require(address(this).balance >= 0, "Insufficient balance.");
                uint256 userShare = (address(this).balance * DA7[msg.sender].allocationRatio) / 100;

                (bool success,) = msg.sender.call{value: userShare}("");
                require(success, "Transfer failed.");
            }else{
                IERC20 token = IERC20(DA3[tokenNames[i]].tokenContract);
                uint256 userShare = (token.balanceOf(address(this)) * DA7[msg.sender].allocationRatio) / 100;
                token.transfer(msg.sender, userShare);
            }

        }
    }

    function getUserOrders(
        address _userAddress
    ) external view returns (uint256[] memory) {
        return DA5[_userAddress].orderNumbers;
    }

    function getTokenOrders(
        string memory _tokenName
    ) external view returns (uint256[] memory) {
        return DA6[_tokenName].orderNumbers;
    }

    function getOrderDetails(
        uint256 _orderNumber
    )
    external
    view
    returns (
        uint256 orderNumber,
        address user,
        string memory tokenName,
        uint256 pledgeAmount,
        uint256 totalAmount,
        uint256 hasWithdraw,
        uint256 creationTimestamp,
        bool redemptionStatus
    )
    {
        Order storage order = DA4[_orderNumber];
        return (
        order.orderNumber,
        order.user,
        order.tokenName,
        order.pledgeAmount,
        order.totalAmount,
        order.hasWithdraw,
        order.createTime,
        order.redemptionStatus
        );
    }



    function feedOver() public  {

        IFeedContract feedCon = IFeedContract(feedAddress);
        require(feedCon.A() == 1,"feed contract status is not true");
        IBEP20 bweToken = IBEP20(DA2);
        uint256 pamount = bweToken.balanceOf(address(this));
        uint256 famount = bweToken.balanceOf(feedAddress);
        if(pamount >= 4 * famount){
            bweToken.transfer(F1,4 * famount);
        }else{
            bweToken.transfer(F1,pamount);
        }

    }

    function compareStrings(string storage a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

}
