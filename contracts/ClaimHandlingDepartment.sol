import "./Garage.sol";
import "./ClaimProcessingDepartement.sol";

contract ClaimHandlingDepartment {

    // Forms Coming from ProcessingDepartment
    
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

    
    enum InsuranceType {
        THIRD_PARTY,
        ALL_RISK
    }

    enum ClaimStatus {
        WAITING_FOR_ASSESSMENT,
        POSITIVE,
        NEGATIVE
    }


    Garage internal garage;
    ClaimProcessingDepartement internal claimProcessingDepartement;

    // Events
    event assessmentPerformed(address client, uint256 AllRiskClaim);
    event garageReceiptReveived(address client);


    constructor(address _garageAddress){
        garage = Garage(_garageAddress);
    }


    function PickupAllriskClaims(ClaimProcessingDepartement.Claim memory claim) external returns(uint256, bool){  
        if(performAssessment(claim)){
            sendNotification(claim.owner, claim.id);
            return garage.EstimateCost(Garage.All_risk_Assessment(claim.damageGravity));
        }else{
            return (0,false);
        }
    }

    function performAssessment(ClaimProcessingDepartement.Claim memory claim) private returns(bool){
        if(claim.status == ClaimProcessingDepartement.ClaimStatus.POSITIVE){
            return true;
        }else{
            return false;
        }
    }

    function sendNotification(address client, uint256 claimId) private {
        emit assessmentPerformed(client, claimId);
    }


}