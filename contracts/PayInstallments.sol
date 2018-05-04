pragma solidity ^0.4.19;

import "./SafeMath.sol";
import "./EMICalculator.sol";
import "./CollectFund.sol";

contract PayInstallments is CollectFund {
    
    uint duePeriod = 30 days;
    uint i = 0;

    struct Installment {
        uint256 installmentAmount;
        uint8 remainingTenure;
    }



    mapping (string => Installment ) mapInstallmentsWithProposal;

    event InstallmentTransfer(string _proposalID, uint256 _amount, address _from, address _to );

    modifier checkInstallmentTenure(string _proposalID) {
        if ( mapInstallmentsWithProposal[_proposalID].remainingTenure > 0) 
        _;
    }

    modifier checkNextDue(string _proposalID) {
        
    }
    
    function calculateInstallment (string _proposalID) returns (uint256 _installmentAmount, uint8 _tenure) {
        BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
        uint256 installmentAmount = EMICalculator.calculateInstallment(currentProposal.fundingGoal, currentProposal.interestRate, currentProposal.tenureInMonths);
        mapInstallmentsWithProposal[_proposalID] = Installment(installmentAmount, currentProposal.tenureInMonths);
    }

    function payInstallment(string _proposalID) payable checkProposalOwner(_proposalID) checkInstallmentTenure(_proposalID) {
        Installment storage currentInstallment = mapInstallmentsWithProposal[_proposalID];
        LenderInfo storage currentLenderInfo;

        for (i = 0; i < mapLendersWithProposal[_proposalID].length ; i++) {
            address currentLender = mapLendersWithProposal[_proposalID][i];
            currentLenderInfo = mapProposalWithLenderInfo[_proposalID][currentLender];
            uint256 amount = SafeMath.div((SafeMath.mul(currentInstallment.installmentAmount, currentLenderInfo.fundRatio)), 100);
            if (currentLender.send(amount)) {
                InstallmentTransfer(_proposalID, amount, mapProposalWithOwner[_proposalID], currentLender);
            }
        }

    }

}