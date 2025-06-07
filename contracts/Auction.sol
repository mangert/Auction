// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

contract Auction {

    error InvalidStartPrice(uint64 startPrice, uint64 minPriceLimit);
    error RequestToStoppedAuction(uint256 index);
    error ExpiredTime(uint256 index);
    error InfucientFunds(uint256 index, uint256 value, uint256 price);    
    
    event NewAuctionCreated(uint256 indexed index, string description, uint32 startPrice, uint32 duration);
    event AuctionEnded(uint256 indexed index, uint32 finalPrice,address indexed buyer);
    
    event MonetTrasferFailed(uint256 indexed index, address indexed recipient, uint256 amount, bytes reason);    
    
    uint32 private constant DURATION = 2 days;
    uint32 private immutable fee = 10;
    address private owner;       
    
    struct  Lot {
        address payable seller;        
        uint32 startPrice;
        uint32 finalPrice;
        uint32 discountRate;
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

    function createAuction(uint32 _startPrice, uint32 _discountRate, uint32 _duration, string calldata _description) external
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

    function getPrice(uint256 index) public view returns(uint32) {
        Lot memory currentAuction = auctions[index];
        require(currentAuction.stopped != true, RequestToStoppedAuction(index));
        uint32 elapsedTime = uint32(block.timestamp - currentAuction.startTime);
        uint32 discount = currentAuction.discountRate * elapsedTime;
        
        return (currentAuction.startPrice - discount);        
    }

    function buy(uint256 index) external payable {
        
        Lot memory lot = auctions[index];
        
        require(!lot.stopped, RequestToStoppedAuction(index));
        require(block.timestamp < lot.endTime, ExpiredTime(index));
        uint32 currentPrice = getPrice(index);
        
        require(msg.value >= currentPrice, InfucientFunds(index, msg.value, currentPrice));
        
        lot.stopped = true;
        lot.finalPrice = currentPrice;
        
        uint256 refund = msg.value - currentPrice;
        if(refund > 0) {
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if(!success) {
                pendingWithdrawals[msg.sender]+=refund;
                emit MonetTrasferFailed(index, msg.sender, refund, "refund failed");    
            }
        }
        uint32 amount = currentPrice - ((currentPrice * fee) / 100);
        (bool success, ) = lot.seller.call{value: amount}("");
        if(!success){
            pendingWithdrawals[lot.seller]+=refund;
            emit MonetTrasferFailed(index, lot.seller, refund, "incom transfer failed");
        }

        emit AuctionEnded(index, currentPrice, msg.sender);
    }

    function withdrawPending() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, InfucientFunds(0, 0, 0));

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed"); //TO - кастомную ошибку сделать
    }

    function withdrawIncomes(uint32 amount) external { //todo
        
        
    }

    function getBalance() public view returns(uint256 balance) {
        balance = address(this).balance;        
    }

     function getBalance2() public view returns(uint256) {
        return address(this).balance;        
    }


        
}

