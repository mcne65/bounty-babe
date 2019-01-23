pragma solidity ^0.5.0;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
      // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
      // benefit is lost if 'b' is also tested.
      // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
    }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0); // Solidity only automatically asserts when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two numbers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

/** @title Bounty Babe */
/** @author Audrey Worsham */
contract BountyBabe {

    using SafeMath for uint;
    uint bountyCount;
    uint submissionCount;
    address admin;
    bool private stopped = false;

    mapping(uint => Bounty) public bounties;
    mapping(uint => Submission) public submissions;
    mapping(uint => mapping(uint => uint)) public bounties_submissions;
    mapping(address => uint[]) public users_bounties;

    // The state of a bounty
    enum BountyState { 
        Open, // The bounty is open and accepting submissions 
        Closed // The bounty has been closed and is no longer accepting submissions
    }
    // The state of a submission
    enum SubmissionState {
        Submitted, // A submission is made for a bounty
        Accepted, // A submission is accepted for a bounty
        Rejected, // A submission is rejected for a bounty
        Paid // The submitter receives paymant for their work
    }

    struct Bounty {
        uint bountyId;
        address payable creator;
        uint amount;
        string description;
        uint numSubmissions;
        BountyState bountyState;
    }

    struct Submission {
        uint bountyId;
        uint submissionId;
        address payable submitter;
        string description;
        SubmissionState submissionState;

    }

    // Events that will be emitted on changes
    event Open(uint indexed bountyId); // Fired upon creation of a bounty
    event Closed(uint indexed bountyId); // Fired when a bounty is no longer taking submissions
    event Submitted(uint indexed bountyId, uint indexed submissionId); // Fired when a submission has been made
    event Accepted(uint indexed bountyId, uint indexed submissionId); // Fired when a submission has been accepted for a bounty
    event Rejected(uint indexed bountyId, uint indexed submissionId); // Fired when a submission has been rejected for a bounty
    event Paid(uint indexed bountyId, uint indexed submissionId); // Fired when the submitter receives payment

    constructor() public {
        admin = msg.sender;
        bountyCount = 0;
        submissionCount = 0;
    }
    // Making sure the bounty is open using the bounty Id
    modifier bountyMustBeOpen(uint bountyId) {
        require(bounties[bountyId].bountyState == BountyState.Open, "Bounty must be open");
        _;
    }

    // Making sure the submission is made using the submission Id
    modifier mustBeSubmitted(uint submissionId) {
        require(submissions[submissionId].submissionState == SubmissionState.Submitted, "Submission must be made");
        _;
    }

    // Making sure the msg.sender of the bounty is the owner
    modifier onlyBountyOwner(uint bountyId) {
        require(bounties[bountyId].creator == msg.sender, "The owner of the bounty is msg.sender");
        _;
    }

    // Making sure the submission is accepted for a bounty
    modifier mustBeAccepted(uint submissionId) {
        require(submissions[submissionId].submissionState == SubmissionState.Accepted, "Submission must be in Accepted state");
        _;
    }

    // Making sure all actions in the contract are suspended if a bug is discovered
    modifier stopInEmergency {
        require(!stopped, "Emergency stop is enabled, this function is disabled");
        _;
    }

    // Making sure the bounty creator can still withdraw funds if a bug is discovered
    modifier onlyInEmergency {
        require(stopped, "Can only be called in an emergency");
        _;
    }

    // Making sure only the admin can access certain functions
    modifier isAdmin() {
        require(msg.sender == admin, "Only the admin can perform this function");
        _;
    }


    /**  @dev Makes sure only the admin can stop the contract
      */
    function toggleContractActive() public isAdmin {
        stopped = !stopped;
    }

    /** @dev Creates a bounty
      * @param description Description of the bounty being created
      * @return The Id of the bounty created
      */
    function createBounty(string memory description) public payable stopInEmergency() returns(uint) {
        require(msg.value > 0, "The amount is invalid");
        uint bountyId = bountyCount;
        emit Open(bountyId);
        bounties[bountyId] = Bounty({
            bountyId: bountyId,
            creator: msg.sender,
            amount: msg.value,
            description: description,
            numSubmissions: 0,
            bountyState: BountyState.Open
        });
        bountyCount = bountyCount.add(1);
        users_bounties[msg.sender].push(bountyId);
        return bountyId;
    }

    /** @dev Creates a submission to a specific bounty
      * @param bountyId The Id of the bounty the submission is for
      * @param description Description of the submission being created
      * @return The Id of the submission created
      */
    function createSubmission(uint bountyId, string memory description)
        public
        bountyMustBeOpen(bountyId)
        stopInEmergency()
        returns(uint)
    {
        uint submissionId = submissionCount;
        uint submissionIndex = bounties[bountyId].numSubmissions;
        
        emit Submitted(bountyId, submissionId);

        submissions[submissionId] = Submission({
            bountyId: bountyId,
            submissionId: submissionId,
            submitter: msg.sender,
            description: description,
            submissionState: SubmissionState.Submitted
        });
        
        bounties_submissions[bountyId][submissionIndex] = submissionId;
        submissionCount = submissionCount.add(1);
        bounties[bountyId].numSubmissions = bounties[bountyId].numSubmissions.add(1);
        return submissionId;
    }

    /** @dev Gets the number of bounties submitted
      * @return The number of bounties submitted
      */
    function getBountyCount() public view returns(uint) {
        return bountyCount;
    }

    /** @dev Gets the total number of submissions
      * @return The total number of submissions
      */
    function getSubmissionCount() public view returns(uint) {
        return submissionCount;
    }

    /** @dev Gets the number of submissions for a bounty
      * @param bountyId The Id of the bounty
      * @return The total number of submissions for that bounty
      */
    function getBountySubmissionCount(uint bountyId) public view returns(uint) {
        return bounties[bountyId].numSubmissions;
    }

    /** @dev Gets the Id of a submission by the index in bounties_submissions array
      * @param bountyId The Id of the bounty
      * @param index The index in the bounties_submissions array
      * @return The bounty's submission id
      */
    function getBountySubmissionIdByIndex(uint bountyId, uint index) public view returns(uint) {
        require(bountyId < bountyCount, "The bounty Id must be less than the bounty count");
        require(index < bounties[bountyId].numSubmissions, "The index must be less than the number of submissions for the bounty");
        return bounties_submissions[bountyId][index];
    }

    /** @dev Gets the user's bounty Id by the user's address and index number
      * @param who The user
      * @param index The index in the users_bounties array
      * @return The user's bounty Id
      */
    function getUserBountyIdByIndex(address who, uint index) public view returns(uint) {
        require(index < users_bounties[who].length, "The index must be less than the number of bounties for the user");
        return users_bounties[who][index];
    }

    /** @dev Retrieves a bounty using a bounty Id
      * @param _bountyId The Id of the bounty
      * @return All aspects of a bounty
      */
    function fetchBounty(
        uint _bountyId
    ) 
        public view 
        returns (
            uint bountyId,
            address creator,
            uint amount,
            string memory description,
            uint numSubmissions,
            uint bountyState
        )
    {
        bountyId = bounties[_bountyId].bountyId;
        creator = bounties[_bountyId].creator;
        amount = bounties[_bountyId].amount;
        description = bounties[_bountyId].description;
        numSubmissions = bounties[_bountyId].numSubmissions;
        bountyState = uint(bounties[_bountyId].bountyState);
        return (bountyId, creator, amount, description, numSubmissions, bountyState);

    }

    /** @dev Retrieves a submission using a submission Id
      * @param _submissionId The Id of the bounty
      * @return All aspects of a submission
      */
    function fetchSubmission(
        uint _submissionId
    )
        public view
        returns (
            uint bountyId,
            uint submissionId,
            address submitter,
            string memory description,
            uint submissionState
        ) 
    {
        bountyId = submissions[_submissionId].bountyId;
        submissionId = submissions[_submissionId].submissionId;
        submitter = submissions[_submissionId].submitter;
        description = submissions[_submissionId].description;
        submissionState = uint(submissions[_submissionId].submissionState);
        return (bountyId, submissionId, submitter, description, submissionState);
    }

    /** @dev Gets the number of bounties a user has submitted
      * @param _who The address of the user
      * @return The number of bounties for the user
      */
    function userNumBounties(address _who) public view returns(uint) {
        return users_bounties[_who].length;
    }

    /** @dev Accepts a submission for a bounty
      * @param bountyId The Id of the bounty
      * @param submissionId The Id of the submission
      * @return True if the submission is accepted
      */
    function acceptSubmission(uint bountyId, uint submissionId)
        public 
        mustBeSubmitted(submissionId)
        onlyBountyOwner(bountyId)
        bountyMustBeOpen(bountyId)
        stopInEmergency()
        returns (bool) 
    {
        submissions[submissionId].submissionState = SubmissionState.Accepted;
        bounties[bountyId].bountyState = BountyState.Closed;
        emit Accepted(bountyId, submissionId);
        emit Closed(bountyId);
        return true;
    }

    /** @dev Rejects a submission for a bounty
      * @param bountyId The Id of the bounty
      * @param submissionId The Id of the submission
      * @return True if the submission is rejected
      */
    function rejectSubmission(uint bountyId, uint submissionId)
        public 
        mustBeSubmitted(submissionId)
        onlyBountyOwner(bountyId)
        bountyMustBeOpen(bountyId)
        stopInEmergency()
        returns (bool)
    {
        submissions[submissionId].submissionState = SubmissionState.Rejected;
        emit Rejected(bountyId, submissionId);
        return true;
    }

    /** @dev Submitter receives payment for bounty
      * @param submissionId The Id of the submission
      * @return True if the submitter is paid
      */
    function withdrawBountyAmount(uint submissionId) public mustBeAccepted(submissionId) returns(bool) {
        require(msg.sender == submissions[submissionId].submitter, "The msg.sender must be the submitter");
        uint bountyId = submissions[submissionId].bountyId;
        submissions[submissionId].submitter.transfer(bounties[bountyId].amount);
        submissions[submissionId].submissionState = SubmissionState.Paid;
        emit Paid(bountyId, submissionId);
        return true;
    }

    /** @dev The creator of a bounty can withdraw his funds
      * @param bountyId The id of the bounty
      * @return True if the funds were withdrawn
      */
    function emergencyWithdraw(uint bountyId)
        public 
        onlyInEmergency()
        onlyBountyOwner(bountyId)
        bountyMustBeOpen(bountyId)
        returns(bool)
    {
        bounties[bountyId].creator.transfer(bounties[bountyId].amount);
        bounties[bountyId].bountyState = BountyState.Closed;
        return true;
    }

    // Fallback function
    function() external payable { 
        require(false, "No message data -- fallback function failed");
    }

}
