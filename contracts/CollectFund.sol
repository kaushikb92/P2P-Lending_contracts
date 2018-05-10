pragma solidity ^0.4.19;

import "./SafeMath.sol";

contract CollectFund {

    uint deadline = 1 days;
    using SafeMath for uint256;
    uint256 length;
    uint256 i;
    uint256 duePeriod = 30 days;
    address admin;

    /*Store proposals raised by borrowers*/
    struct BorrowerProposal {
        uint256 fundingGoal;                                //Funding goal in Ether
        uint8 interestRate;                                 //Rate of interest offered by borrower in the proposal
        uint256 fundingReached;                             //Proposal funding reached
        uint8 tenureInMonths;                               //Proposal loan duration
        uint256 installmentStartTS;                         //If proposal goal achieved proposal start timestamp 
    }

    /*Store lender contribution information per proposal per lender address*/
    struct LenderInfo {
        uint256 amount;                                     //Contributed amount
        uint8 fundRatio;                                    //Store contribution ration in an unsigned integer format
    }

    /*Store contributed proposals per lender*/
    struct LenderContributions{
        bytes32[] proposalID;                               //Store contributed proposal ids
    }

    mapping (string => BorrowerProposal) mapProposalsWithProposalIDs;                   //map proposal information with proposal ids
    mapping (string => uint256) mapProposalWithDeadline;                                //map proposal expiration with proposal ids, default 1 day
    mapping (address => string[]) mapBorrowerWithProposalIDs;                           //map borrower's raised porposals with his address
    mapping (string => address) mapProposalWithOwner;                                   //map proposal ids with proposal owners/borrower's address
    mapping (string => bool) proposalOpen;                                              //map proposal ids with activity status
    mapping (string => mapping(address =>LenderInfo)) mapProposalWithLenderInfo;        //map proposal ids and contributer's address with contribution - 2d
    mapping (string => address[]) mapLendersWithProposal;                               //map proposal ids with contributers
    mapping (address => LenderContributions) mapProposalIDsWithLenders;                 //map contributer's information with contributed proposal ids
    mapping (string => uint256) mapProposalIDWithNextDueDate;                           //map next instllment due date with proposal/loan ids


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

    modifier onlyAdmin() {
        if (msg.sender == admin) {
            _;
        }
    }

    function CollectFund() {
        admin = msg.sender;
    }

    /*Borrower proposal submission with generated proposal id, proposal funding goal, rate of interest and loan tenure */
    function submitProposal(string _proposalID, uint256 _fundingGoal, uint8 _interestRate, uint8 _tenureInMonths) external {
        mapProposalsWithProposalIDs[_proposalID] = BorrowerProposal(_fundingGoal,_interestRate,0, _tenureInMonths,0);
        mapBorrowerWithProposalIDs[msg.sender].push(_proposalID);
        mapProposalWithDeadline[_proposalID] = now+deadline;
        mapProposalWithOwner[_proposalID] = msg.sender;
        proposalOpen[_proposalID] = true;
    }

    /*Lend Ethers to proposal by proposal id*/
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

    /*Admin to close proposal after deadline and successful funding*/
    function reachedGoal(string _proposalID) onlyAdmin afterDeadline(_proposalID) external {
        BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
        if (currentProposal.fundingReached == currentProposal.fundingGoal) {
            proposalOpen[_proposalID] == false;
            currentProposal.installmentStartTS = now;
            setNextDueDate(_proposalID);
            GoalReached(mapProposalWithOwner[_proposalID], _proposalID, currentProposal.fundingGoal);
        }
        else{
            throw;
        }

    }

    /*Contract internal function to set next installment due date*/
    function setNextDueDate(string _proposalID) internal {
        uint256 installmentStart = getInstallmentStartTS(_proposalID);
        if (mapProposalIDWithNextDueDate[_proposalID] == 0){
            mapProposalIDWithNextDueDate[_proposalID] = installmentStart + duePeriod;
        }
        else {
            mapProposalIDWithNextDueDate[_proposalID] = mapProposalIDWithNextDueDate[_proposalID] + duePeriod;
        }
    }

    /*Get installment due date by proposal/loan id*/
    function getProposalDueDate(string _proposalID) view returns(uint256) {
        if (mapProposalIDWithNextDueDate[_proposalID] == 0){
            return getInstallmentStartTS(_proposalID);
        }
        else {
            return mapProposalIDWithNextDueDate[_proposalID];
        }
    }

    /*Get days left in installment due date by proposal/loan id*/
    function getDaysRemainingInInstallmentDue(string _proposalID) view returns(uint256) {
        if (getProposalDueDate(_proposalID) > now) {
            return (getProposalDueDate(_proposalID) - now);
        }
        else {
            return 0;
        }
    }

    /*Get funding as borrower if proposal was successful to be triggered by proposal owner by proposal id*/
    function getMoneyAsBorrowerAfterDeadline(string _proposalID) payable afterDeadline(_proposalID) proposalGoalReached(_proposalID) checkProposalOwner(_proposalID) external {
        address proposalOwner = mapProposalWithOwner[_proposalID];
        BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
        if (proposalOwner.send(currentProposal.fundingGoal)) {
            GetFundAfterGoalReached(proposalOwner, _proposalID, currentProposal.fundingGoal);
        }
    }

    /*Get proposal submission timestamp by proposal id */
    function getProposalStartTS(string _proposalID) view external returns(uint256) {
        return mapProposalsWithProposalIDs[_proposalID].installmentStartTS;

    }

    /*Check funding reached by proposal id*/
    function checkProposalFunding(string _proposalID) view external returns(uint256){
        return (mapProposalsWithProposalIDs[_proposalID].fundingReached);
    }

    /* */
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

    function getInstallmentStartTS(string _proposalID) view proposalGoalReached(_proposalID) returns(uint256) {
        return (mapProposalsWithProposalIDs[_proposalID].installmentStartTS);
    }

}