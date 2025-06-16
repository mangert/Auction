import { dropTransaction } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { loadFixture, ethers, expect } from "./setup";
import { network } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Auction", function() {
    async function deploy() {        
        const [user0, user1, user2] = await ethers.getSigners();
        
        const auction_Factory = await ethers.getContractFactory("Auction");
        const auction = await auction_Factory.deploy();
        await auction.waitForDeployment();        

        return { user0, user1, user2, auction }
    }

    describe("deployment tеsts", function() {
        it("should be deployed", async function() {
            const { auction } = await loadFixture(deploy);        
            
            expect(auction.target).to.be.properAddress;                    
    
        });
    
        it("should have 0 eth by default", async function() {
            const { auction } = await loadFixture(deploy);
    
            const balance = await ethers.provider.getBalance(auction.target);        
            expect(balance).eq(0);
            
        });     

    });

    describe("create funtion tests", function() {

        it("should create auction", async function(){
            const {user0, auction } = await loadFixture(deploy);
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            const tx = await auction.createAuction(startPrice, discountRate, duration, item);
            tx.wait(1);
            
            const countAucitons = await auction.getCount();
            expect(countAucitons).eq(1);
           
            const createdAuction = await auction.auctions(0);
            expect(createdAuction.seller).eq(user0.address);
            expect(createdAuction.startPrice).eq(startPrice);
            expect(createdAuction.stopped).eq(false);
            await expect(tx).to.emit(auction, "NewAuctionCreated").withArgs(0, item, startPrice, duration);

        
        });

        it("should be reverted creating with low start price", async function(){
            
            const {user0, auction } = await loadFixture(deploy);
            const startPrice = 100n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            await expect(auction.createAuction(startPrice, discountRate, duration, item))
                    .revertedWith("Uncorrect start price");                    

        });
    });

    describe("Buy and get fucnctions", function() {
        
        it("should get auction info", async function(){
            
            const {user0, auction } = await loadFixture(deploy);
            
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) {
                
                const tx = await auction.createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);
            }

            const lot = await auction.getLot(3);

            expect(lot.description).eq(item + "3");           

        
        });

        it("should be reverted request non-existent lot", async function(){
            
            const {user0, auction } = await loadFixture(deploy);
            
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) {
                
                const tx = await auction.createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);
            }

            await expect(auction.getLot(5)).revertedWith("Non Existent lot");
        });
        
        it("should buy lot", async function(){ //проверка функции buy
            const {user0, user1, user2, auction } = await loadFixture(deploy);
            
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) { //сначала создадим 4 лота
                
                const tx = await auction.connect(user1).createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);                
            }
            
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 12 * 60 * 60; // 12 часов
            const futureTime = now + timeToAdd;

            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");

            //теперь попробуем купить
            const index = 3n; //попробуем купить третий лот
            const price = await auction.getPrice(index);  //получаем цену лота                     

            const buyTx = await auction.connect(user2).buy(index, {value: price}); //покупаем
            
            const lot3 = await auction.getLot(index); //получаем данные купленного лота            
            const finalPrice = lot3.finalPrice;

            //тестируем событие
            await expect(buyTx).to.emit(auction, "AuctionEnded").withArgs(index, finalPrice, user2);            
            
            //проверяем балансы
            const sellerIncome = finalPrice - ((finalPrice * 10n) / 100n);
            const auctionIncome = (finalPrice * 10n) / 100n;            

            await expect(buyTx).to.changeEtherBalances([user1, user2, auction.target],[sellerIncome, -finalPrice, auctionIncome]);
        
        });

        it("should revert buy with not enough funds", async function(){ //проверка возврата функции buy из-аз недостаточности средств
            const {user0, user1, user2, auction } = await loadFixture(deploy);
            
            //сначала выставим на продажу несколько лотов
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) { //сначала создадим 4 лота
                
                const tx = await auction.connect(user1).createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);                
            }
            
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 12 * 60 * 60; // 12 часов
            const futureTime = now + timeToAdd;

            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");

            //теперь попробуем купить
            const index = 3n; //попробуем купить третий лот
            const price = await auction.getPrice(index) / 2n;  //получаем цену лота                     
            
            await expect(auction.connect(user2).buy(index, {value: price})).revertedWith("Not enough funds");
        });

        it("should be reverted buy non-existent lot", async function(){ //проверка отклонения функции buy при попытке покупки несуществующего лота
            
            const {user0, auction } = await loadFixture(deploy);
            
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) {
                
                const tx = await auction.createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);
            }

            await expect(auction.buy(5, {value: startPrice})).revertedWith("Non Existent lot");
        });

        it("should revert buy lot from stopped auction", async function(){ //проверка возврата функции buy при повторной покупке
            const {user0, user1, user2, auction } = await loadFixture(deploy);
            
            //сначала выставим на продажу несколько лотов
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) { //сначала создадим 4 лота
                
                const tx = await auction.connect(user1).createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);                
            }
            
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 12 * 60 * 60; // 12 часов
            const futureTime = now + timeToAdd;

            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");

            //теперь сначала делаем покупку, чтобы перевести аукцион в стоп
            const index = 3n; //будем дважды покупать третий лот
            const price = await auction.getPrice(index);  //получаем цену лота                     
;
            const tx  = await auction.connect(user2).buy(index, {value: price});
            tx.wait(1);
            
            await expect(auction.connect(user2).buy(index, {value: price})).revertedWith("Auction stopped");
        });

        it("should revert buy lot with expired time", async function(){ //проверка возврата функции buy при истечении срока
            const {user0, user1, user2, auction } = await loadFixture(deploy);
            
            //сначала выставим на продажу несколько лотов
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) { //сначала создадим 4 лота
                
                const tx = await auction.connect(user1).createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);                
            }
            
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 48 * 60 * 60; // 48 часов
            const futureTime = now + timeToAdd;

            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");

            //теперь сначала делаем покупку, чтобы перевести аукцион в стоп
            const index = 3n; //будем покупать третий лот
            const price = await auction.getPrice(index);  //получаем цену лота            
            
            await expect(auction.connect(user2).buy(index, {value: price})).revertedWith("Time expired");
        });

        it("should buy lot and save refunds in mapping", async function(){ //проверка 
            const {user0, user1, user2, auction } = await loadFixture(deploy);
            
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) { //сначала создадим 4 лота
                
                const tx = await auction.connect(user1).createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);                
            }
            
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 12 * 60 * 60; // 12 часов
            const futureTime = now + timeToAdd;

            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");

            //теперь попробуем купить
            const index = 3n; //попробуем купить третий лот
            const price = await auction.getPrice(index);  //получаем цену лота                     

            const buyTx = await auction.connect(user2).buy(index, {value: price}); //покупаем
            
            const lot3 = await auction.getLot(index); //получаем данные купленного лота            
            const finalPrice = lot3.finalPrice;

            //тестируем событие
            await expect(buyTx).to.emit(auction, "AuctionEnded").withArgs(index, finalPrice, user2);            
            
            //проверяем балансы
            const sellerIncome = finalPrice - ((finalPrice * 10n) / 100n);
            const auctionIncome = (finalPrice * 10n) / 100n;            

            await expect(buyTx).to.changeEtherBalances([user1, user2, auction.target],[sellerIncome, -finalPrice, auctionIncome]);
        
        });
        

    });

    describe("withdraw funcitons", function() {   
        
        async function getBadReciever() { //вспомогательная функция создания "сбоящего" получателя средств

            const badReceiverFactory = await ethers.getContractFactory("BadReceiver");
            const badReceiver = await badReceiverFactory.deploy();            
            await badReceiver.waitForDeployment();

            const [sender] = await ethers.getSigners();            

            //пускай на контракте будут средства - 1 эфир
            const tx = await badReceiver.connect(sender).getTransfer({value: ethers.parseEther("1.0")})                         

            return badReceiver;
        }

        it("should buy lot and save refunds in mapping", async function(){ //проверка неуспешного рефанда и ручного вывода сдачи
            const {user0, user1, user2, auction } = await loadFixture(deploy);
            const badReceiver = await getBadReciever(); //наш "покупатель"
           
            const recieverBalance = await ethers.provider.getBalance(badReceiver);        
            
            const startPrice = 1000000000n;
            const duration = 1n*24n*60n*60n;
            const item = "example";
            const discountRate = 10n;

            for(let i = 0n; i != 4n; ++i) { //сначала создадим 4 лота
                
                const tx = await auction.connect(user1).createAuction(startPrice + i, discountRate, duration, item + i);
                tx.wait(1);                
            }
            
            const now = (await ethers.provider.getBlock("latest"))!.timestamp;
            const timeToAdd = 12 * 60 * 60; // 12 часов
            const futureTime = now + timeToAdd;

            await network.provider.send("evm_setNextBlockTimestamp", [futureTime]);
            await network.provider.send("evm_mine");

            //теперь попробуем купить
            const index = 3n; //попробуем купить третий лот
            const price = await auction.getPrice(index);  //получаем цену лота                     
            
            //TO - транзу сделать
            
            const lot3 = await auction.getLot(index); //получаем данные купленного лота            
            const finalPrice = lot3.finalPrice;

            const refund = price - finalPrice;

            console.log(refund);           
            
            
        });
    

    });


});