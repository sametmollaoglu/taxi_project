pragma solidity >=0.7.0 <0.8.0;

contract taxiProject {

    address payable contractWallet; //deployer address
    uint contractBalance; //ide deployer balance 

    uint participationFee;
    uint maintenanceAndTaxCost;

    uint participantCount; //number of participant

    CarDealer carDealer;

    mapping (address => Participant) participantMap;
    address[] participantAddrList;

    Car car;

    Driver driver;
    Driver driverPropose;
    mapping (address => Participant) participantToDriverVotesMap;
    uint driverVotes=0;

    mapping (address => Participant) participantToFireDriverVotesMap;
    uint fireDriverVotes=0;

    uint lastPayDividendTime=0; //when participants take last profits

    uint purchaseCarVotes=0;

    uint sellCarVotes=0;

    uint amountOfCharge =0;


    constructor() {
        contractWallet = msg.sender;
        contractBalance = 0;
        participationFee = 100 ether;  //for each participants
        maintenanceAndTaxCost = 10 ether; //every 6 months
        participantCount= 0;

    }

    struct Car {
        uint ID;
        uint price;
        uint offerValidTime;
        uint proposeTime;
        bool approvalState;
    }
    
    struct Participant {
        address payable participantAddr;
        uint balance;
        bool voteToPurchase;
        bool voteToSell;
        bool voteToDriver;
        bool voteToFireDriver;
    }

    struct Driver {
        address payable driverAddr;  
        uint salary;
        bool isExist; 
        uint256 lastSalaryTime;
        uint balance;
    }

    struct CarDealer {
        address payable carDealerAddr;
        uint balance;
        uint lastMaintenanceAndTaxTime;
    }

    function Join() public payable{
        require(participantCount < 9, "Not enough place!");
        require(participantMap[msg.sender].participantAddr != msg.sender, "already joined");
        require(msg.value >= participationFee, "not enough money!");
        
        participantCount++;
        contractWallet.transfer(participationFee);
        participantMap[msg.sender] = Participant(msg.sender, msg.value - participationFee, false, false, false, false);
        if(msg.value-participationFee >0){msg.sender.transfer(msg.value-participationFee);}
        contractBalance += participationFee;   

        participantAddrList.push(msg.sender);
    }

    function setCarDealer(address payable _carDealerAddr) public{
        carDealer.carDealerAddr = _carDealerAddr;
    }

    modifier onlyCarDealer(){
        require(msg.sender == carDealer.carDealerAddr);
        _;
    }

    function CarProposeToBusiness(uint ID, uint price, uint offerValidTime) public onlyCarDealer{
        car = Car(ID, price, offerValidTime, block.timestamp, false);
    }

    modifier onlyParticipant(){
        require(msg.sender == participantMap[msg.sender].participantAddr);
        _;
    }

    function ApprovePurchaseCar(bool paramVote) public onlyParticipant{
        if(participantMap[msg.sender].voteToPurchase != false &&
                participantMap[msg.sender].voteToPurchase != true){
            participantMap[msg.sender].voteToPurchase=paramVote;
            if(paramVote==true){
                purchaseCarVotes++;
            }
        }
        
        if(participantCount/2 < purchaseCarVotes){
            return PurchaseCar();
        }
    }

    function PurchaseCar() public payable {
        require(car.offerValidTime > block.timestamp-car.proposeTime, "no valid time to buy!");
        require(contractBalance >= car.price, "not enough money!");
        carDealer.carDealerAddr.transfer(car.price); //cardealer takes the car cost
        carDealer.balance += car.price;
        if(contractWallet.send(car.price)){  //car prices substracted from contract balance
            revert();
        }
        contractBalance-=car.price;  //car prices substracted from contract balance in ide
        purchaseCarVotes=0;
        carDealer.lastMaintenanceAndTaxTime=block.timestamp; //holds the time of the car purchase
    }

    function RepurchaseCarPropose(uint ID, uint price, uint offerValidTime) public onlyCarDealer{
        car = Car(ID, price, offerValidTime, block.timestamp, false);
    }

    function ApproveSellProposal(bool paramVote) public payable onlyParticipant{
        if(participantMap[msg.sender].voteToSell != false &&
                participantMap[msg.sender].voteToSell != true){
            participantMap[msg.sender].voteToSell=paramVote;
            if(paramVote==true){
                sellCarVotes++;
            }
        }
        
        if(participantCount/2 < sellCarVotes){
            return RepurchaseCar();
        }
    }

    function RepurchaseCar() public payable {
        require(car.offerValidTime > block.timestamp-car.proposeTime, "no valid time to buy!");
        require(carDealer.balance >= car.price, "not enough money!");
        contractWallet.transfer(car.price); //contractWallet takes the car cost
        contractBalance += car.price;
        if(carDealer.carDealerAddr.send(car.price)){  //car prices substracted from carDealer
            revert();
        }
        carDealer.balance-=car.price;  //car prices substracted from carDealer balance in ide
        sellCarVotes=0;
    }

    function ProposeDriver(uint salary) public{
        require(driver.isExist != true , "driver is already exist");
        require(driverPropose.isExist != true , "proposed driver is already exist");
        driverPropose = Driver(msg.sender, salary, true, 0, 0);
        
    }

    function ApproveDriver(bool paramVote) public onlyParticipant{
        if(participantToDriverVotesMap[msg.sender].voteToDriver != false &&
                participantToDriverVotesMap[msg.sender].voteToDriver != true){
            participantToDriverVotesMap[msg.sender].voteToDriver=paramVote;
            if(paramVote==true){
                driverVotes++;
            }
        }
        
        if(participantCount/2 < driverVotes){
            return SetDriver();
        }
    }

    function SetDriver() public {
        driver = driverPropose;
        driver.isExist = true;
        driver.lastSalaryTime=block.timestamp;
        driverPropose.isExist=false;
    }

    function ProposeFireDriver(bool paramVote) public onlyParticipant{
        if(participantToFireDriverVotesMap[msg.sender].voteToFireDriver != false &&
                participantToFireDriverVotesMap[msg.sender].voteToFireDriver != true){
            participantToFireDriverVotesMap[msg.sender].voteToFireDriver=paramVote;
            if(paramVote==true){
                fireDriverVotes++;
            }
        }
        
        if(participantCount/2 < fireDriverVotes){
            return FireDriver();
        }
    }

    function FireDriver() public payable{
        driver.driverAddr.transfer(driver.balance);
        driver = Driver(address(0), 0, false, 0, 0);
    }

    modifier onlyDriver(){
        require(msg.sender == driver.driverAddr);
        _;
    }


    function LeaveJob() public payable onlyDriver{
        FireDriver();
    }
    
    event moneySent(address customer, address contractWallet, uint amountOfCharge);
    function GetCharge() public payable{
        emit moneySent(msg.sender, contractWallet, amountOfCharge);
        contractBalance += amountOfCharge;
    }

    function GetSalary() public payable onlyDriver{
        require(((block.timestamp - driver.lastSalaryTime)/ 60 / 60 / 24) >= 30,"it's not the end of the month");
        
        driver.balance+=driver.salary;
        if(contractWallet.send(driver.salary)) {
            revert();
        }

        contractBalance-=driver.salary;
        driver.driverAddr.transfer(driver.balance);
        driver.balance=0;
        driver.lastSalaryTime=block.timestamp;

    }

    function CarExpenses() public payable onlyParticipant{
        require(((block.timestamp - carDealer.lastMaintenanceAndTaxTime)/ 60 / 60 / 24) >= 180,"it's not the end of the 6 month");
        carDealer.carDealerAddr.transfer(maintenanceAndTaxCost);
        carDealer.balance += maintenanceAndTaxCost;

        if(contractWallet.send(maintenanceAndTaxCost)) {
            revert();
        }
        contractBalance -= maintenanceAndTaxCost;

        carDealer.lastMaintenanceAndTaxTime = block.timestamp;
    }    
    
    function PayDividend() public onlyParticipant{
        require(lastPayDividendTime == 0 || ((block.timestamp - lastPayDividendTime)/ 60 / 60 / 24) >= 180 ,"it's not the end of the 6 month");
        GetSalary();
        CarExpenses();

        for(uint x=0; x<participantAddrList.length; x++){
            participantMap[participantAddrList[x]].balance += contractBalance/participantAddrList.length;
        }
        contractBalance=0;
    }

    function GetDividend() public payable onlyParticipant{
        require(participantMap[msg.sender].balance>0, "there is no money in balance");
        msg.sender.transfer(participantMap[msg.sender].balance);
        participantMap[msg.sender].balance=0;
            
        if(contractWallet.send(participantMap[msg.sender].balance)) {
            revert();
        }        
    }
}
