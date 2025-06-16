// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./../Auction.sol";

/**
 * @title BadReceiver  
 * @notice примитивный контракт, который отклоняет поступления средств - для проведения тестов 
 * на "неуспешные" перечисления средств
 */
contract BadReceiver {

    address auction = 0x5FbDB2315678afecb367f032d93F642f64180aa3;    

    function getTransfer() external payable{} //функция для пополнения контракта


    function  getBalance() external view returns(uint256) { //возвращаем баланс
        return address(this).balance;
    }    

    function getAuctionRefunds() external payable {
        
        (bool success, ) = auction.call(abi.encodeCall(Auction.withdrawPending, ()));
        require(success, "Withdraw error");        
    }

    receive() external payable { //отклняем все поступления, не инициированные этим контрактом
        revert("Reject all ETH");
    }
}
