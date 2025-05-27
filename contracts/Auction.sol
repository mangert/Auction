// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

contract Auction {

    error InvalidStartPrice(uint64 startPrice, uint64 minPriceLimit);
    event NewAuctionCreated();
    
    uint32 private constant DURATION = 2 days;
    uint256 private immutable fee = 10;
    address private owner;    

    struct  Lot {
        address payable seller;        
        uint64 startPrice;
        uint64 finalPrice;
        uint256 startTime;
        uint256 endTime;
        uint64 discountRate;
        string description;
        bool stopped;        
    }
    Lot[] public auctions;
    
    constructor() {
        owner = msg.sender;        
    }

    function createAuction(uint64 _startPrice, uint64 _discountRate, uint64 _duration, string calldata _description) external
    {
        uint64 duration = _duration == 0 ? DURATION : _duration;        
        require(_startPrice >= _discountRate * duration, InvalidStartPrice(_startPrice, _discountRate * duration));

        Lot memory newLot = Lot({
            seller: payable (msg.sender),
            startPrice: _startPrice,             
            finalPrice: _startPrice,
            startTime: block.timestamp,
            endTime: duration + block.timestamp, 
            discountRate: _discountRate, 
            description: _description,
            stopped: false
        });

        auctions.push(newLot);
        emit NewAuctionCreated();
        
    }
}

