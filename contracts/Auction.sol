// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

contract Auction {

    error InvalidStartPrice(uint64 startPrice, uint64 minPriceLimit);
    error RequestToStoppedAuction(uint256 index);
    error ExpiredTime(uint256 index);
    error InfucientFunds(uint256 index, uint256 value, uint256 price);    
    
    event NewAuctionCreated(uint256 indexed index, string description, uint32 startPrice, uint32 duration);
    event AuctionEnded(uint256 indexed index, uint64 finalPrice,address indexed buyer);
    
    event MoneyTrasferFailed(uint256 indexed index, address indexed recipient, uint256 amount, bytes reason);    
    
    uint32 private constant DURATION = 2 days;
    uint32 private immutable fee = 10;
    address private owner;       
    
    struct  Lot {
        address payable seller;        
        uint64 startPrice;
        uint64 finalPrice;
        uint64 discountRate;
        uint32 startTime;
        uint32 endTime;        
        string description;
        bool stopped;        
    }
    Lot[] public auctions;
    mapping (address => uint256) pendingWithdrawals;
    
    constructor() {
        owner = msg.sender;        
    }

    function createAuction(uint32 _startPrice, uint64 _discountRate, uint32 _duration, string calldata _description) external
    {
        uint32 duration = _duration == 0 ? DURATION : _duration;        
        require(_startPrice >= _discountRate * duration, InvalidStartPrice(_startPrice, _discountRate * duration));

        Lot memory newLot = Lot({
            seller: payable (msg.sender),
            startPrice: _startPrice,             
            finalPrice: _startPrice,
            startTime: uint32(block.timestamp),
            endTime: duration + uint32(block.timestamp), 
            discountRate: _discountRate, 
            description: _description,
            stopped: false
        });

        auctions.push(newLot);                
        emit NewAuctionCreated(auctions.length - 1, _description, _startPrice, duration);        
    }

    function getPrice(uint256 index) public view returns(uint64) {
        Lot memory currentAuction = auctions[index];
        require(currentAuction.stopped != true, RequestToStoppedAuction(index));
        uint32 elapsedTime = uint32(block.timestamp - currentAuction.startTime);
        uint64 discount = currentAuction.discountRate * elapsedTime;
        
        return (currentAuction.startPrice - discount);        
    }

    function buy(uint256 index) external payable { //функция для покупки лота
        
        require(index <= getCount(), "Non Existent lot"); //проверка на наличие лотаё
        
        Lot memory lot = auctions[index]; //здесь делаем копию из storage, в оптимизированном варианте будет ссылка
        
        require(!lot.stopped, RequestToStoppedAuction(index)); //проверяем, что аукцион по этом лоту не завершен
        require(block.timestamp < lot.endTime, ExpiredTime(index)); //проверяем, что время не истекло
        
        //начинаем собственно покупку
        uint64 currentPrice = getPrice(index); //считаем текущую цену
        require(msg.value >= currentPrice, InfucientFunds(index, msg.value, currentPrice)); //проверяем, что заплатили достаточно
        
        lot.stopped = true; //завершаем аукцион
        lot.finalPrice = currentPrice; //записываем цену в данные лота
        
        uint256 refund = msg.value - currentPrice; //считаем излишки
        
        if(refund > 0) { //возвращаем излишки
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if(!success) {
                pendingWithdrawals[msg.sender]+=refund;
                emit MoneyTrasferFailed(index, msg.sender, refund, "refund failed");    
            }
        }
        
        uint64 amount = currentPrice - ((currentPrice * fee) / 100); //считаем сумму для продавца (комиссию оставляем себе)
        (bool success, ) = lot.seller.call{value: amount}(""); //отправляем деньги продавцу
        if(!success){
            pendingWithdrawals[lot.seller]+=refund;
            emit MoneyTrasferFailed(index, lot.seller, refund, "incom transfer failed");
        }

        auctions[index] = lot; //копируем модифицированные данные лота обратно в storage - в оптимизированном варианте этой строки не будет 

        emit AuctionEnded(index, currentPrice, msg.sender); 
    }

    function withdrawPending() external { //функция для ручного вывода "зависших" средств пользователей
        
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, InfucientFunds(0, 0, 0));

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    function withdrawIncomes(uint64 amount) external {
        require(msg.sender == owner, "Not an owner");
        require(amount <= getBalance(), "Not enough funds");
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");        
        
    }

    function getBalance() public view returns(uint256 balance) {
        balance = address(this).balance;        
    }

    function getBalance2() public view returns(uint256) { //убрать?
        return address(this).balance;        
    }

    function getCount() public view returns(uint256) {
        return auctions.length;
    }

    function getLot(uint256 index) external view returns(Lot memory) {
        require(index <= getCount(), "Non Existent lot"); 
        return auctions[index];
    }
        
}

