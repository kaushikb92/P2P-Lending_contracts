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
        uint256 proposalSubmissionTS;                         //If proposal goal achieved proposal start timestamp 
    }

    struct ProposalIDs{
        bytes32 proposalID;
    }

    ProposalIDs[] public AllProposalIDs;

    /*Store lender contribution information per proposal per lender address*/
    struct LenderInfo {
        uint256 amount;                                     //Contributed amount
        uint8 fundRatio;                                    //Store contribution ration in an unsigned integer format
    }

    /*Store contributed proposals per lender*/
    struct LenderContributions{
        bytes32[] proposalID;                               //Store contributed proposal ids
    }

    mapping (bytes32 => BorrowerProposal) mapProposalsWithProposalIDs;                   //map proposal information with proposal ids
    mapping (bytes32 => uint256) mapProposalWithDeadline;                                //map proposal expiration with proposal ids, default 1 day
    mapping (address => bytes32[]) mapBorrowerWithProposalIDs;                           //map borrower's raised porposals with his address
    mapping (bytes32 => address) mapProposalWithOwner;                                   //map proposal ids with proposal owners/borrower's address
    mapping (bytes32 => bool) mapProposalOpenStatusWithProposalID;                                              //map proposal ids with activity status
    mapping (bytes32 => mapping(address =>LenderInfo)) mapProposalWithLenderInfo;        //map proposal ids and contributer's address with contribution - 2d
    mapping (bytes32 => address[]) mapLendersWithProposal;                               //map proposal ids with contributers
    mapping (address => LenderContributions) mapProposalIDsWithLenders;                 //map contributer's information with contributed proposal ids
    mapping (bytes32 => uint256) mapProposalIDWithNextDueDate;                           //map next instllment due date with proposal/loan ids
    mapping (bytes32 => bool) mapProposalSuccessStatusWithProposalID;
    mapping (bytes32 => uint256) mapProposalWithInstallmentStartTS;


    event EtherTransfer(address _from, uint256 _value);                                             
    event GoalReached(address _proposalOwner, bytes32 _proposalID, uint256 _fundingGoal);            
    event GetFundAfterGoalReached(address _proposalOwner, bytes32 _proposalID, uint256 _amount);
    event WithdrawFundWhenGoalNotReached(address _lender, bytes32 _proposalID, uint256 _amount);

    modifier checkDeadline(bytes32 _proposalID, uint256 _ts) {
        if (_ts <= mapProposalWithDeadline[_proposalID])
        _;
    }

    modifier afterDeadline(bytes32 _proposalID, uint256 _ts) {
        if (_ts >= mapProposalWithDeadline[_proposalID])
        _;
    }

    modifier checkProposalOwner(bytes32 _proposalID) {
        if ( msg.sender == mapProposalWithOwner[_proposalID])
        _;
    }

    modifier checkProposalStatus(bytes32 _proposalID) {
        if ( mapProposalOpenStatusWithProposalID[_proposalID])
        _;
    }

    modifier proposalGoalReached(bytes32 _proposalID) {
        if ( !mapProposalOpenStatusWithProposalID[_proposalID])
        _;
    }

    modifier fundingOverflow(bytes32 _proposalID, uint256 _amount) {
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
    function submitProposal(bytes32 _proposalID, uint256 _fundingGoal, uint8 _interestRate, uint8 _tenureInMonths, address _borrower, uint256 _ts) external {
        mapProposalsWithProposalIDs[_proposalID] = BorrowerProposal(_fundingGoal,_interestRate,0, _tenureInMonths,_ts);
        mapBorrowerWithProposalIDs[_borrower].push(_proposalID);
        mapProposalWithDeadline[_proposalID] = _ts+deadline;
        mapProposalWithOwner[_proposalID] = _borrower;
        mapProposalOpenStatusWithProposalID[_proposalID] = true;
        mapProposalSuccessStatusWithProposalID[_proposalID] = false;
        AllProposalIDs.push(ProposalIDs(_proposalID)); 
    }

    /*Lend Ethers to proposal by proposal id*/
    function lendMoneyToProposal(bytes32 _proposalID, uint256 _amount, address _lender, uint256 _ts) payable fundingOverflow(_proposalID,_amount) checkDeadline(_proposalID,_ts) checkProposalStatus(_proposalID) external {
        if (msg.value > 0 ) {
            BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
            currentProposal.fundingReached = SafeMath.add(currentProposal.fundingReached,_amount);
            LenderInfo memory currentLender;
            currentLender.amount = _amount;
            currentLender.fundRatio = uint8(SafeMath.div((SafeMath.mul(_amount, 100)),(currentProposal.fundingGoal)));
            mapProposalWithLenderInfo[_proposalID][_lender] = currentLender;
            mapLendersWithProposal[_proposalID].push(_lender);
            mapProposalIDsWithLenders[_lender].proposalID.push(_proposalID);       
            EtherTransfer(_lender,_amount);
        }
    }

    /*Admin to close proposal after deadline and successful funding*/
    function checkGoalReached(bytes32 _proposalID, uint256 _ts) onlyAdmin afterDeadline(_proposalID,_ts) external {
        BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
        if (currentProposal.fundingReached == currentProposal.fundingGoal) {
            mapProposalOpenStatusWithProposalID[_proposalID] == false;
            mapProposalWithInstallmentStartTS[_proposalID] = _ts;
            setNextDueDate(_proposalID);
            mapProposalSuccessStatusWithProposalID[_proposalID] = true;
            GoalReached(mapProposalWithOwner[_proposalID], _proposalID, currentProposal.fundingGoal);
        }
        else{
            mapProposalOpenStatusWithProposalID[_proposalID] == false;
            mapProposalSuccessStatusWithProposalID[_proposalID] == false;
        }

    }

    /*Contract internal function to set next installment due date*/
    function setNextDueDate(bytes32 _proposalID) internal {
        uint256 installmentStart = getInstallmentStartTS(_proposalID);
        if (mapProposalIDWithNextDueDate[_proposalID] == 0){
            mapProposalIDWithNextDueDate[_proposalID] = installmentStart + duePeriod;
        }
        else {
            mapProposalIDWithNextDueDate[_proposalID] = mapProposalIDWithNextDueDate[_proposalID] + duePeriod;
        }
    }

    function getProposalDetailsByProposalID(bytes32 _proposalID) external view returns(uint256,uint8,uint256,uint8,uint256,bool,bool) {
        return (mapProposalsWithProposalIDs[_proposalID].fundingGoal,
        mapProposalsWithProposalIDs[_proposalID].interestRate,
        mapProposalsWithProposalIDs[_proposalID].fundingReached,
        mapProposalsWithProposalIDs[_proposalID].tenureInMonths,
        mapProposalsWithProposalIDs[_proposalID].proposalSubmissionTS,
        mapProposalSuccessStatusWithProposalID[_proposalID],
        mapProposalOpenStatusWithProposalID[_proposalID]);
    }

    /*Get installment due date by proposal/loan id*/
    function getProposalDueDate(bytes32 _proposalID) view returns(uint256) {
        if (mapProposalIDWithNextDueDate[_proposalID] == 0){
            return getInstallmentStartTS(_proposalID);
        }
        else {
            return mapProposalIDWithNextDueDate[_proposalID];
        }
    }

    function getProposalTenure(bytes32 _proposalID) view internal returns(uint8) {
        return mapProposalsWithProposalIDs[_proposalID].tenureInMonths;
    }

    function getBorrowerSuccessfulProposals(address _borrower) view returns(bytes32[]) {
        length = mapBorrowerWithProposalIDs[_borrower].length;
        bytes32[] memory proposalIDs = new bytes32[](length);
        bytes32[] memory successfulProposals = new bytes32[](length);
        proposalIDs = mapBorrowerWithProposalIDs[_borrower];
        for (i = 0; i < length; i++) {
            bytes32 currentProposalID = proposalIDs[i];
            if (mapProposalSuccessStatusWithProposalID[currentProposalID]) {
                successfulProposals[i] = currentProposalID;
            }
        }
        return (successfulProposals);
    }

    /*Get days left in installment due date by proposal/loan id*/
    function getDaysRemainingInInstallmentDue(bytes32 _proposalID, uint256 _ts) view returns(uint256) {
        if (getProposalDueDate(_proposalID) > _ts) {
            return (getProposalDueDate(_proposalID) - _ts);
        }
        else {
            return 0;
        }
    }

    /*Get funding as borrower if proposal was successful to be triggered by proposal owner by proposal id*/
    function getMoneyAsBorrowerAfterDeadline(bytes32 _proposalID, uint256 _ts) payable afterDeadline(_proposalID, _ts) proposalGoalReached(_proposalID) checkProposalOwner(_proposalID) external {
        address proposalOwner = mapProposalWithOwner[_proposalID];
        BorrowerProposal storage currentProposal = mapProposalsWithProposalIDs[_proposalID];
        if (proposalOwner.send(currentProposal.fundingGoal)) {
            GetFundAfterGoalReached(proposalOwner, _proposalID, currentProposal.fundingGoal);
        }
    }

    /*Check funding reached by proposal id*/
    function checkProposalFunding(bytes32 _proposalID) view external returns(uint256) {
        return (mapProposalsWithProposalIDs[_proposalID].fundingReached);
    }

    /* */
    function getProposalExpiration(bytes32 _proposalID) view external returns(uint256) {
        return mapProposalWithDeadline[_proposalID];
    }

    function getProposalOwner(bytes32 _proposalID) view external returns(address) {
        return mapProposalWithOwner[_proposalID];
    }

    function getProposalLendersWithDetails(bytes32 _proposalID) view external returns(address[],uint256[], uint8[]) {
        length = mapLendersWithProposal[_proposalID].length;
        address[] memory lenderAddresses = new address[](length);
        uint256[] memory lenderContributions = new uint256[](length);
        uint8[] memory lenderFundRatios = new uint8[](length);
        lenderAddresses = mapLendersWithProposal[_proposalID];
        for ( i = 0 ; i < length; i++) {
            address currentLender = lenderAddresses[i];
            lenderContributions[i] = mapProposalWithLenderInfo[_proposalID][currentLender].amount;
            lenderFundRatios[i] = mapProposalWithLenderInfo[_proposalID][currentLender].fundRatio;
        }
        return (lenderAddresses,lenderContributions,lenderFundRatios);
    }

    function getLenderDetails(bytes32 _proposalID, address _lender) view external returns(uint256, uint8) {
    return (mapProposalWithLenderInfo[_proposalID][_lender].amount, mapProposalWithLenderInfo[_proposalID][_lender].fundRatio);
    }

    function getBorrrowerSpecificProposals(address _borrower) view external returns(bytes32[]) {
        return (mapBorrowerWithProposalIDs[_borrower]);
    }

    function getAllProposalsForBorrowerList() view external returns(bytes32[]) {
        length = AllProposalIDs.length;
        bytes32[] memory activeProposals = new bytes32[](length);
        for (i = 0; i < length; i++) {
            ProposalIDs memory currentProposalID;
            currentProposalID = AllProposalIDs[i];
            if (mapProposalOpenStatusWithProposalID[currentProposalID.proposalID]) {
                activeProposals[i] = currentProposalID.proposalID;
            }
        }
        return (activeProposals);
    }

    function getLenderSuccessfulProposals(address _lender) view external returns(bytes32[]) {
        length = mapProposalIDsWithLenders[_lender].proposalID.length;
        bytes32[] memory lenderContributedProposals = new bytes32[](length);
        bytes32[] memory successfulProposals = new bytes32[](length);
        lenderContributedProposals = mapProposalIDsWithLenders[_lender].proposalID;
        for (i = 0; i < length; i++ ) {
            bytes32 currentProposalID = lenderContributedProposals[i];
            if (mapProposalSuccessStatusWithProposalID[currentProposalID]) {
                successfulProposals[i] = currentProposalID;
            }
        }
        return (successfulProposals);
    }

    /*Get proposal submission timestamp by proposal id */
    function getInstallmentStartTS(bytes32 _proposalID) view proposalGoalReached(_proposalID) returns(uint256) {
        return (mapProposalWithInstallmentStartTS[_proposalID]);
    }

}