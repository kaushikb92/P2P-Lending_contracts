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

    function getDueInstallment(bytes32 _proposalID, uint256 _ts) view returns (uint256 _installment, uint256 _nextDueDate, uint8 _remainingTenure) { 
        if (getDaysRemainingInInstallmentDue(_proposalID,_ts) > 0) {
            return (mapInstallmentsWithProposal[_proposalID].installmentAmount,getProposalDueDate(_proposalID),getProposalTenure(_proposalID)) ;
        }
        else {
            return ((mapInstallmentsWithProposal[_proposalID].installmentAmount + lateInstallmentFee),getProposalDueDate(_proposalID),getProposalTenure(_proposalID));
        }
    }

    function payInstallment(bytes32 _proposalID, uint256 _ts) payable checkProposalOwner(_proposalID) checkInstallmentTenure(_proposalID) proposalGoalReached(_proposalID) {
        Installment storage currentInstallment = mapInstallmentsWithProposal[_proposalID];
        LenderInfo storage currentLenderInfo;
        uint256 getCurrentInstallment;
        (getCurrentInstallment,,) = getDueInstallment(_proposalID, _ts);
        if (msg.value == getCurrentInstallment) {
            for (i = 0; i < mapLendersWithProposal[_proposalID].length ; i++) {
            address currentLender = mapLendersWithProposal[_proposalID][i];
            currentLenderInfo = mapProposalWithLenderInfo[_proposalID][currentLender];
            uint256 amount = SafeMath.div((SafeMath.mul(currentInstallment.installmentAmount, currentLenderInfo.fundRatio)), 100);
            if (currentLender.send(amount)) {
                InstallmentTransfer(_proposalID, amount, mapProposalWithOwner[_proposalID], currentLender);
                setNextDueDate(_proposalID);
                if (currentInstallment.remainingTenure == 0){
                    currentInstallment.remainingTenure = getProposalTenure(_proposalID) - 1;
                }
                else {
                    currentInstallment.remainingTenure -= 1;
                }
               }
            }
        }
    }

}