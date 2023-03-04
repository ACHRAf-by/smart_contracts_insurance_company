import "./ClaimHandlingDepartment.sol";

contract ClaimProcessingDepartement {
    struct Car {
        string matricule;
        uint256 power;
        uint8 flag;
    }
    struct Client {
        address id;
        string name;
        string email;
        Car car;
        uint8 flag;
    }

    struct Expert {
        address id;
        string name;
        string email;
        uint8 flag;
    } 

    enum InsuranceType {
        THIRD_PARTY,
        ALL_RISK
    }

    struct Insurance {
        address clientId;
        InsuranceType insuranceType;
        uint256 subscriptionDate;
        uint256 expirationDate;
        bool isRevoked;
        uint8 flag;
    }
    enum ClaimStatus {
        WAITING_FOR_ASSESSMENT,
        POSITIVE,
        NEGATIVE
    }

    struct Claim {
        uint256 id;
        InsuranceType insuranceType;
        // Scale between 1 to 10
        uint256 damageGravity;
        uint256 damageCost;
        ClaimStatus status;
        address owner;
    }

    struct Report {
        address client;
        uint256 claimId;
        uint256 percentageToBePaid;
    }

    struct ThirdPartyAssessment {
        uint256 percent;
        bool accepted;
    }



    // Attributes
    mapping(address => Client) clients;
    mapping(address => Expert) experts;
    mapping(address => Insurance) insurances;
    mapping(address => mapping(uint256 => Claim)) public assessments;
    mapping(address => Report[]) reports;
    uint256 public ASSESSENT_CURRENT_ID;
    uint256 public allRiskPrice;
    uint256 public thirdPartyPrice;
    uint256 public validity;
    uint256 public assessmentsThreshold;
    ClaimHandlingDepartment private claimHandlingDepartement;
    address private owner;
    // Event
    event UserCreated(address id);
    event ExpertCreated(address id);
    event InsuranceSubscribed(address id);
    event InvalidClaimPolicy(address id,string email);
    event AssessmentRejectedEvent(uint256 claimId);
    event ClientPaid(address client, uint256 amount);
    event AssessmentProcessed(address client, uint256 claimId);

    constructor(
        uint256 _allRiskPrice,
        uint256 _thirdPartyPrice,
        uint256 _validity,
        uint256 _assessmentsThreshold,
        address _claimHandlingDepartement
    ) {
        thirdPartyPrice = _thirdPartyPrice;
        allRiskPrice = _allRiskPrice;
        validity = _validity;
        assessmentsThreshold = _assessmentsThreshold;
        ASSESSENT_CURRENT_ID = 1;
        owner = msg.sender;
        claimHandlingDepartement = ClaimHandlingDepartment(_claimHandlingDepartement);
    }

    function createClient(
        string memory name,
        string memory email,
        string memory matricule,
        uint256 power
    ) public {
        clients[msg.sender] = Client(
            msg.sender,
            name,
            email,
            Car(matricule, power, 1),
            1
        );
        emit UserCreated(msg.sender);
    }

    function createExpert(
        string memory name,
        string memory email
    ) public {
        experts[msg.sender] = Expert(
            msg.sender,
            name,
            email,
            1
        );
        emit ExpertCreated(msg.sender);
    }

    function subscribeInsurance(InsuranceType insuranceType)
        public
        payable
        isClient
        hasCar
    {
        uint256 amountToPay = computeAmount(
            insuranceType,
            clients[msg.sender].car
        );
        require(msg.value >= amountToPay, "Not enough ethers");
        insurances[msg.sender] = Insurance(
            msg.sender,
            insuranceType,
            block.timestamp,
            block.timestamp + validity,
            false,
            1
        );
        emit InsuranceSubscribed(msg.sender);
    }

    function computeAmount(InsuranceType insuranceType, Car storage car)
        private
        view
        returns (uint256)
    {
        uint256 total = 0;
        if (insuranceType == InsuranceType.THIRD_PARTY) {
            total += thirdPartyPrice;
        } else if (insuranceType == InsuranceType.THIRD_PARTY) {
            total += allRiskPrice;
        }
        if (car.power < 100) {
            total += 2000;
        } else if (car.power >= 100 && car.power < 200) {
            total += 2500;
        } else if (car.power >= 200) {
            total += 3000;
        }
        return total;
    }

    function getProfile() view public returns(address, uint8,string memory, string memory){
        Client memory client = clients[msg.sender];
        return (
            client.id,
            client.flag,
            client.name,
            client.email
        );
    }

    function getInsurance() view public returns(InsuranceType, uint256, uint256,bool) {
        Insurance memory insurance = insurances[msg.sender];
        return (
            insurance.insuranceType,
            insurance.subscriptionDate,
            insurance.expirationDate,
            insurance.isRevoked
        );
    }


    function claimProcessing(InsuranceType insuranceType,  uint256 damageGravity,  uint256 damageCost) public isClient hasCar hasInsurance(insuranceType) {
        Claim memory claim = Claim(
            ASSESSENT_CURRENT_ID++,
            insuranceType,
            damageGravity,
            damageCost,
            ClaimStatus.WAITING_FOR_ASSESSMENT,
            msg.sender
        );
        if(checkClaimPolicy()){
             if (claim.insuranceType == InsuranceType.ALL_RISK) {
               claimProcessingAllRisk(claim);
            } else if (claim.insuranceType == InsuranceType.THIRD_PARTY) {
               claimProcessingThirdParty(claim);
            }

        }else{
            emit InvalidClaimPolicy(msg.sender,clients[msg.sender].email);
        }   
    }

    function claimProcessingAllRisk(Claim memory claim) private {
        bool check1 = policyCheck(claim);
        
        claim.status = ClaimStatus.POSITIVE;
        if(check1){
            (uint256 receipe, bool repairsAuth) = claimHandlingDepartement.PickupAllriskClaims(claim);
            if(repairsAuth){
                payClient(msg.sender,receipe);
                emit ClientPaid(msg.sender, receipe);
            }else{
                claim.status = ClaimStatus.NEGATIVE;
            }
            notifyClient(msg.sender,claim);
        }
        assessments[msg.sender][claim.id] = claim;
    }

    function claimProcessingThirdParty(Claim memory claim) private {
        // Store assement for further analysis
        claim.status = ClaimStatus.WAITING_FOR_ASSESSMENT;
        assessments[msg.sender][claim.id] = claim;
    }

    function submitExpertReport(address client,uint256 claimId, uint256 percentageToBePaid) public isExpert{
        Claim memory claim = assessments[client][claimId];
        if(checkAssessments(claim)){
            claim.status = ClaimStatus.POSITIVE;
            payClient(client,claim.damageCost * (percentageToBePaid/100));
            emit ClientPaid(client, claim.damageCost * percentageToBePaid);
        }else{
            claim.status = ClaimStatus.NEGATIVE;
        }
        assessments[client][claimId] = claim;
        notifyClient(client,claim);
    }

    function getClaimById(uint256 claimId) view public isClient returns(uint256, InsuranceType,uint256, uint256,ClaimStatus)   {
        Claim memory claim = assessments[msg.sender][claimId];
        return (
            claim.id,
            claim.insuranceType,
            claim.damageGravity,
            claim.damageCost,
            claim.status
        );
    }
    function notifyClient(address client, Claim memory claim) private {
        emit AssessmentProcessed(client,claim.id);
    }

    function payClient(address client, uint256 cost) private {
        payable(client).send(ToEth(cost));
    }

    function checkAssessments(Claim memory claim) private returns(bool){
        if(claim.damageGravity < assessmentsThreshold){
            return true;
        }else{
            emit AssessmentRejectedEvent(claim.id);
            return false;
        }
    }

    function policyCheck(Claim memory claim) private returns(bool){
        return true;
    }

    function checkClaimPolicy() view private returns(bool){
        if(insurances[msg.sender].expirationDate < block.timestamp){
            return false;
        }
        return true;
    }

    function ToEth(uint256 cost) view private returns(uint256) {
        //We convert to ETH then to WEI
        return uint256(cost * (10**18) / getLatestPrice());
    }

    function getLatestPrice() private view returns (uint256) {
        // We put a static value but we should retrieve the real value by using an oracle
        return 1200;
    }


    receive() external payable{}

    modifier hasInsurance(InsuranceType insuranceType){
        require(insurances[msg.sender].insuranceType == insuranceType, "Invalid insurance type");
        _;
    }

    modifier isClient() {
        require(clients[msg.sender].flag == 1, "User does not exist");
        _;
    }

    modifier hasCar() {
        require(clients[msg.sender].car.flag == 1, "User does not have car");
        _;
    }

    modifier isOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    modifier isExpert(){
        require(experts[msg.sender].flag == 1, "You are not an expert");
        _;
    } 

}
