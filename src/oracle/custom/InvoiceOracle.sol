// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract InvoiceOracle {
    error NotOwner();
    error NotSubmitter();
    error NotChallenger();
    error InvalidValue();
    error InvalidDisputeWindow();
    error ZeroAddress();
    error SubmissionAlreadyActive();
    error SubmissionNotFound();
    error SubmissionAlreadyDisputed();
    error SubmissionDisputed();
    error SubmissionNotDisputed();
    error DisputeWindowExpired();
    error DisputeWindowNotExpired();
    error NoFinalizedValue();

    struct Submission {
        uint256 value;
        address submitter;
        uint64 submittedAt;
        uint64 disputeDeadline;
        bool disputed;
        bool exists;
    }

    struct FinalizedValue {
        uint256 value;
        uint64 finalizedAt;
        bool exists;
    }

    address public owner;
    uint256 public immutable DISPUTE_WINDOW;

    mapping(address => bool) public isSubmitter;
    mapping(address => bool) public isChallenger;

    mapping(bytes32 => Submission) public activeSubmissions;
    mapping(bytes32 => FinalizedValue) public finalizedValues;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlySubmitter() {
        if (!isSubmitter[msg.sender]) revert NotSubmitter();
        _;
    }

    modifier onlyChallenger() {
        if (!isChallenger[msg.sender]) revert NotChallenger();
        _;
    }

    event SubmissionCreated(
        bytes32 indexed invoiceId, uint256 value, address indexed submitter, uint64 disputeDeadline
    );
    event SubmissionMarkedDisputed(bytes32 indexed invoiceId, address challenger);
    event SubmissionFinalized(bytes32 indexed invoiceId, uint256 value);
    event SubmissionCancelled(bytes32 indexed invoiceId);

    constructor(uint256 disputeWindow_) {
        if (disputeWindow_ == 0) revert InvalidDisputeWindow();
        owner = msg.sender;
        DISPUTE_WINDOW = disputeWindow_;
    }

    function submit(bytes32 invoiceId, uint256 value) external onlySubmitter {
        if (value == 0) revert InvalidValue();

        Submission storage submission = activeSubmissions[invoiceId];

        if (submission.exists) revert SubmissionAlreadyActive();

        submission.value = value;
        submission.submitter = msg.sender;
        uint64 timestamp = uint64(block.timestamp);
        submission.submittedAt = timestamp;
        // casting to uint64 is safe because timestamps and dispute window are bounded
        // forge-lint: disable-next-line(unsafe-typecast)
        submission.disputeDeadline = timestamp + uint64(DISPUTE_WINDOW);
        submission.disputed = false;
        submission.exists = true;

        emit SubmissionCreated(invoiceId, value, msg.sender, submission.disputeDeadline);
    }

    function dispute(bytes32 invoiceId) external onlyChallenger {
        Submission storage submission = activeSubmissions[invoiceId];

        if (!submission.exists) revert SubmissionNotFound();

        if (submission.disputed) revert SubmissionAlreadyDisputed();

        if (block.timestamp >= submission.disputeDeadline) revert DisputeWindowExpired();

        submission.disputed = true;

        emit SubmissionMarkedDisputed(invoiceId, msg.sender);
    }

    function finalize(bytes32 invoiceId) external {
        Submission storage submission = activeSubmissions[invoiceId];

        if (!submission.exists) revert SubmissionNotFound();

        if (submission.disputed) revert SubmissionDisputed();

        if (block.timestamp < submission.disputeDeadline) revert DisputeWindowNotExpired();

        uint256 value = submission.value;

        finalizedValues[invoiceId] = FinalizedValue({value: value, finalizedAt: uint64(block.timestamp), exists: true});

        delete activeSubmissions[invoiceId];

        emit SubmissionFinalized(invoiceId, value);
    }

    function cancelDisputedSubmission(bytes32 invoiceId) external onlyOwner {
        Submission storage submission = activeSubmissions[invoiceId];

        if (!submission.exists) revert SubmissionNotFound();

        if (!submission.disputed) revert SubmissionNotDisputed();

        delete activeSubmissions[invoiceId];

        emit SubmissionCancelled(invoiceId);
    }

    function getFinalizedValue(bytes32 invoiceId) external view returns (uint256) {
        FinalizedValue storage value = finalizedValues[invoiceId];

        if (!value.exists) revert NoFinalizedValue();

        return value.value;
    }
}
