// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/**
 * @title Auction  
 * @notice Контракт, позволяющий размещать и покупать лоты на аукционе (неоптимизированная версия)
 */
contract Auction {    
    
    //описание событий
    /**
     * @notice создан новый аукцион по лоту
     */
    event NewAuctionCreated(uint256 indexed index, string description, uint32 startPrice, uint32 duration);
    /**
     * @notice аукцион завершен
     */
    event AuctionEnded(uint256 indexed index, uint64 finalPrice,address indexed buyer);
    
    /**
     * @notice перечисление средств завершщилось неудачей
     */
    event MoneyTrasferFailed(uint256 indexed index, address indexed recipient, uint256 amount, bytes reason);    
    
    uint32 private constant DURATION = 2 days; //значение длительности "по умолчанию"
    uint32 private immutable fee = 10; //комиссия организатора
    address private owner; //владелец контракта - организатора      
    
    struct  Lot { //описание структуры лота
        address payable seller;  //продавец      
        uint64 startPrice; // начальная цена
        uint64 finalPrice; // окончательная цена
        uint64 discountRate; //снижение цены в единицу времени
        uint32 startTime; //время начала
        uint32 endTime;   //время окончания     
        string description; //описание лота
        bool stopped; //статус аукциона       
    }
    
    Lot[] public auctions; //хранилице лотов
    
    mapping (address => uint256) pendingWithdrawals; //хранилище средств, которые не были вовремя перечислены получателям в случае сбоев
    
    constructor() {
        owner = msg.sender;        
    }
     /**
      * @notice функция создания аукциона по лоту
      * @param _startPrice - начальная цена
      * @param _discountRate - размер снижения цены в единицу времени
      * @param _duration - длительность аукциона по лоту
      * @param _description - описание лота
      */
    function createAuction(uint32 _startPrice, uint64 _discountRate, uint32 _duration, string calldata _description) external
    {
        uint32 duration = _duration == 0 ? DURATION : _duration; //если длительность не задана, берем параметр по умолчанию       
        
        //начальная цена должна быть такой, чтобы не уйти в минус за время аукциона
        require(_startPrice >= _discountRate * duration, "Uncorrect start price");

        Lot memory newLot = Lot({ //заполняем данные лота
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

    /**
     * @notice функция для получения актуальной на момент времениц цены лота
     * @param index - идентификатор лота
     * @return актуальная на момент запроса цена лота
     */
    function getPrice(uint256 index) public view returns(uint64) {
        Lot memory currentAuction = auctions[index];
        require(currentAuction.stopped != true, "Auction stopped");
        uint32 elapsedTime = uint32(block.timestamp - currentAuction.startTime);
        uint64 discount = currentAuction.discountRate * elapsedTime;
        
        return (currentAuction.startPrice - discount);        
    }

    /**
     * @notice функция для приобретения лота
     * @param index - идентификатор лота
     */
    function buy(uint256 index) external payable {
        
        require(index <= getCount(), "Non Existent lot"); //проверка на наличие лота
        
        Lot memory lot = auctions[index]; //здесь делаем копию из storage, в оптимизированном варианте будет ссылка
        
        require(!lot.stopped, "Auction stopped"); //проверяем, что аукцион по этом лоту не завершен
        require(block.timestamp < lot.endTime, "Time expired"); //проверяем, что время не истекло
        
        //начинаем собственно покупку
        uint64 currentPrice = getPrice(index); //считаем текущую цену
        require(msg.value >= currentPrice, "Not enough funds"); //проверяем, что заплатили достаточно
        
        lot.stopped = true; //завершаем аукцион
        lot.finalPrice = currentPrice; //записываем цену в данные лота
        
        uint256 refund = msg.value - currentPrice; //считаем излишки
        
        if(refund > 0) { //возвращаем излишки
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if(!success) { //если перевод провалился, записываем "долг" перед пользователем
                pendingWithdrawals[msg.sender]+=refund;
                emit MoneyTrasferFailed(index, msg.sender, refund, "refund failed");    
            }
        }
        
        uint64 amount = currentPrice - ((currentPrice * fee) / 100); //считаем сумму для продавца (комиссию оставляем себе)
        (bool success, ) = lot.seller.call{value: amount}(""); //отправляем деньги продавцу
        if(!success){ //если перевод провалился, записываем "долг" перед пользователем
            pendingWithdrawals[lot.seller]+=amount; 
            emit MoneyTrasferFailed(index, lot.seller, amount, "incom transfer failed");
        }

        auctions[index] = lot; //копируем модифицированные данные лота обратно в storage - в оптимизированном варианте этой строки не будет 

        emit AuctionEnded(index, currentPrice, msg.sender); 
    }

    /**
     * @notice функция для ручного вывода "зависших" средств пользователей
     */
    function withdrawPending() external {
        
        uint256 amount = pendingWithdrawals[msg.sender]; //смотрим, сколько у пользователя "зависло" средств
        require(amount > 0, "Zero withdraw"); //проверка, что невыведенные средства больше нуля

        pendingWithdrawals[msg.sender] = 0; //обнуляем баланс

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    /**
     * @notice функция для вывода доходов организатора торгов
     * @param amount - сумма вывода
     */
    function withdrawIncomes(uint64 amount) external {
        require(msg.sender == owner, "Not an owner"); //проверяем, что выводит владелец контракта
        require(amount <= getBalance(), "Not enough funds"); //проверяем, что нужная сумма есть на балансе
        
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");        
        
    }
    //геттеры
    /**
     * @notice функция возращает баланс контракта
     */
    function getBalance() public view returns(uint256 balance) {
        balance = address(this).balance;        
    }    

    /**
     * @notice функция возращает количество всех аукционов
     */    
    function getCount() public view returns(uint256) {
        return auctions.length;
    }

    /**
     * @notice функция возращает данные по заданному лоту
     * @param index - идентифиактор лота
     */
    function getLot(uint256 index) external view returns(Lot memory) {
        require(index <= getCount(), "Non Existent lot"); 
        return auctions[index];
    }        
}

