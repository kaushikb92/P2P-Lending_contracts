pragma solidity ^0.4.19;

import "./SafeMath.sol";
import "./EMICalculator.sol";
import "./CollectFund.sol";

contract PayInstallments is CollectFund {
    
    uint256 i = 0;
    uint256 lateInstallmentFee;

    struct Installment {
        uint256 installmentAmount;
        uint8 remainingTenure;
    }

    mapping (bytes32 => Installment ) mapInstallmentsWithProposal;

    event InstallmentTransfer(bytes32 _proposalID, uint256 _amount, address _from, address _to );

    modifier checkInstallmentTenure(bytes32 _proposalID) {
        if ( mapInstallmentsWithProposal[_proposalID].remainingTenure > 0) 
        _;
    }   

    function setLateInstallmentFee (uint256 _amount) onlyAdmin {
        lateInstallmentFee = _amount;
    }
    
    function calculateInstallment (bytes32 _proposalID) returns (uint256 _installmentAmount) {
        BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
        uint256 installmentAmount = EMICalculator.calculateInstallment(currentProposal.fundingGoal, currentProposal.interestRate, currentProposal.tenureInMonths);
        mapInstallmentsWithProposal[_proposalID] = Installment(installmentAmount, currentProposal.tenureInMonths);
        return mapInstallmentsWithProposal[_proposalID].installmentAmount;
    }

    function getDueInstallment(bytes32 _proposalID) view returns (uint256 _installment) { 
        if (getDaysRemainingInInstallmentDue(_proposalID) > 0) {
            return mapInstallmentsWithProposal[_proposalID].installmentAmount;
        }
        else {
            return (mapInstallmentsWithProposal[_proposalID].installmentAmount + lateInstallmentFee);
        }
    }

    function payInstallment(bytes32 _proposalID) payable checkProposalOwner(_proposalID) checkInstallmentTenure(_proposalID) {
        Installment storage currentInstallment = mapInstallmentsWithProposal[_proposalID];
        LenderInfo storage currentLenderInfo;
        if (msg.value == getDueInstallment(_proposalID)){
            for (i = 0; i < mapLendersWithProposal[_proposalID].length ; i++) {
            address currentLender = mapLendersWithProposal[_proposalID][i];
            currentLenderInfo = mapProposalWithLenderInfo[_proposalID][currentLender];
            uint256 amount = SafeMath.div((SafeMath.mul(currentInstallment.installmentAmount, currentLenderInfo.fundRatio)), 100);
            if (currentLender.send(amount)) {
                InstallmentTransfer(_proposalID, amount, mapProposalWithOwner[_proposalID], currentLender);
                setNextDueDate(_proposalID);
               }
            }
        }
    }

}