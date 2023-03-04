pragma solidity ^0.8.7;
contract Garage{

   // Attributes
   // Should be retrieved from the previous contract
   struct All_risk_Assessment {
       uint256 _damage;
   }
   

    // Garage features
    // Estimate damage cost
    function EstimateCost(All_risk_Assessment memory assessment)
        external 
        returns(uint256, bool)
   {
    
       uint256 receipe;
       bool repairsAuth = false;
       if(assessment._damage <= 100){
            receipe = 1000;
            repairsAuth = true;
        }
        else if(assessment._damage > 100 || assessment._damage >= 200){
            receipe = 2000;
            repairsAuth = true;
        }
        else if(assessment._damage > 200 || assessment._damage <= 300){
            receipe = 3000;
            repairsAuth = true;
        }
        else {
            receipe = 0;
            repairsAuth = false;
        }
       return(receipe, repairsAuth);
   }
}