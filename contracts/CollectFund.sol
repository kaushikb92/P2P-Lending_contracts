pragma solidity ^0.4.19;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";

contract CollectFund {

    uint deadline = 1 days;
    using SafeMath for uint256;
    uint256 length;
    uint256 i;

    struct BorrowerProposal {
        uint256 fundingGoal;
        uint8 interestRate;
        uint256 fundingReached;
        uint8 tenureInMonths;
        uint256 installmentStartTS;
    }

    struct LenderInfo {
        // address lender;
        uint256 amount;
        uint8 fundRatio;
    }

    struct LenderContributions{
        bytes32[] proposalID;
    }

    mapping (string => BorrowerProposal) mapProposalsWithProposalIDs;
    mapping (string => uint256) mapProposalWithDeadline; 
    mapping (address => string[]) mapBorrowerWithProposalIDs;
    mapping (string => address) mapProposalWithOwner;
    mapping (string => bool) proposalOpen;
    mapping (string => mapping(address =>LenderInfo)) mapProposalWithLenderInfo;
    mapping (string => address[]) mapLendersWithProposal;
    mapping (address => LenderContributions) mapProposalIDsWithLenders;


    event EtherTransfer(address _from, uint256 _value);
    event GoalReached(address _proposalOwner, string _proposalID, uint256 _fundingGoal);
    event GetFundAfterGoalReached(address _proposalOwner, string _proposalID, uint256 _amount);
    event WithdrawFundWhenGoalNotReached(address _lender, string _proposalID, uint256 _amount);

    modifier checkDeadline(string _proposalID) {
        if (now <= mapProposalWithDeadline[_proposalID])
        _;
    }

    modifier afterDeadline(string _proposalID) {
        if (now >= mapProposalWithDeadline[_proposalID])
        _;
    }

    modifier checkProposalOwner(string _proposalID) {
        if ( msg.sender == mapProposalWithOwner[_proposalID])
        _;
    }

    modifier checkProposalStatus(string _proposalID) {
        if ( proposalOpen[_proposalID])
        _;
    }

    modifier proposalGoalReached(string _proposalID) {
        if ( !proposalOpen[_proposalID])
        _;
    }

    modifier fundingOverflow(string _proposalID, uint256 _amount) {
        if (_amount <= (mapProposalsWithProposalIDs[_proposalID].fundingGoal - mapProposalsWithProposalIDs[_proposalID].fundingReached))
        _;
    }

    function submitProposal(string _proposalID, uint256 _fundingGoal, uint8 _interestRate, uint8 _tenureInMonths) external {
        mapProposalsWithProposalIDs[_proposalID] = BorrowerProposal(_fundingGoal,_interestRate,0, _tenureInMonths,0);
        mapBorrowerWithProposalIDs[msg.sender].push(_proposalID);
        mapProposalWithDeadline[_proposalID] = now+deadline;
        mapProposalWithOwner[_proposalID] = msg.sender;
        proposalOpen[_proposalID] = true;
    }

    function lendMoneyToProposal(string _proposalID, bytes32 _proposalId) payable fundingOverflow(_proposalID,msg.value) checkDeadline(_proposalID) checkProposalStatus(_proposalID) external {
        if (msg.value > 0 ) {
            BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
            currentProposal.fundingReached = SafeMath.add(currentProposal.fundingReached,msg.value);
            LenderInfo memory currentLender;
            currentLender.amount = msg.value;
            currentLender.fundRatio = uint8(SafeMath.div((SafeMath.mul(msg.value, 100)),(currentProposal.fundingGoal)));
            mapProposalWithLenderInfo[_proposalID][msg.sender] = currentLender;
            mapLendersWithProposal[_proposalID].push(msg.sender);
            mapProposalIDsWithLenders[msg.sender].proposalID.push(_proposalId);       
            EtherTransfer(msg.sender,msg.value);
        }
    }

    function reachedGoal(string _proposalID) checkProposalOwner(_proposalID) external {
        BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
        if (currentProposal.fundingReached == currentProposal.fundingGoal) {
            proposalOpen[_proposalID] == false;
            currentProposal.installmentStartTS = now;
            GoalReached(mapProposalWithOwner[_proposalID], _proposalID, currentProposal.fundingGoal);
        }
        else{
            throw;
        }

    }

    function getMoneyAsBorrowerAfterDeadline(string _proposalID) payable afterDeadline(_proposalID) proposalGoalReached(_proposalID) external {
        address proposalOwner = mapProposalWithOwner[_proposalID];
        BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
        if (proposalOwner.send(currentProposal.fundingGoal)) {
            GetFundAfterGoalReached(proposalOwner, _proposalID, currentProposal.fundingGoal);
        }
    }

    function getProposalStartTS(string _proposalID) external returns(uint256) {
        return mapProposalsWithProposalIDs[_proposalID].installmentStartTS;

    }

    function checkProposalFunding(string _proposalID) view external returns(uint256){
        return (mapProposalsWithProposalIDs[_proposalID].fundingReached);
    }

    function getProposalExpiration(string _proposalID) view external returns(uint256){
        return mapProposalWithDeadline[_proposalID];
    }

    function getProposalLenders(string _proposalID) view external returns(address[]){
        return (mapLendersWithProposal[_proposalID]);
    }

    function getLenderDetails(string _proposalID, address _lender) view external returns(uint256, uint8) {
    return (mapProposalWithLenderInfo[_proposalID][_lender].amount, mapProposalWithLenderInfo[_proposalID][_lender].fundRatio);
    }

    function getLenderProposals() view external returns(bytes32[]) {
        bytes32[] memory lenderContributedProposals = new bytes32[](mapProposalIDsWithLenders[msg.sender].proposalID.length);
        lenderContributedProposals = mapProposalIDsWithLenders[msg.sender].proposalID;
        return (lenderContributedProposals);
    }

}