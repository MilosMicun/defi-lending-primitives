// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {InvoiceOracle} from "../../../src/oracle/custom/InvoiceOracle.sol";

contract InvoiceOracleTest is Test {
    InvoiceOracle internal oracle;

    address internal owner;
    address internal submitter;
    address internal challenger;
    address internal stranger;

    bytes32 internal constant INVOICE_ID = keccak256("invoice-1");
    bytes32 internal constant INVOICE_ID_2 = keccak256("invoice-2");

    uint256 internal constant VALUE = 1_000e18;
    uint256 internal constant DISPUTE_WINDOW = 3 days;

    function setUp() public {
        owner = makeAddr("owner");
        submitter = makeAddr("submitter");
        challenger = makeAddr("challenger");
        stranger = makeAddr("stranger");

        vm.prank(owner);
        oracle = new InvoiceOracle(DISPUTE_WINDOW);

        vm.startPrank(owner);
        oracle.setSubmitter(submitter, true);
        oracle.setChallenger(challenger, true);
        vm.stopPrank();
    }

    function test_Submit_HappyPath() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        (
            uint256 submittedValue,
            address recordedSubmitter,
            uint64 submittedAt,
            uint64 disputeDeadline,
            bool disputed,
            bool exists
        ) = oracle.activeSubmissions(INVOICE_ID);

        assertEq(submittedValue, VALUE);
        assertEq(recordedSubmitter, submitter);
        assertTrue(exists);
        assertFalse(disputed);
        assertEq(submittedAt, block.timestamp);
        assertEq(disputeDeadline, block.timestamp + DISPUTE_WINDOW);
    }

    function test_Submit_EmitsSubmissionCreated() public {
        vm.prank(submitter);

        vm.expectEmit(true, false, true, true);
        emit InvoiceOracle.SubmissionCreated(INVOICE_ID, VALUE, submitter, uint64(block.timestamp + DISPUTE_WINDOW));

        oracle.submit(INVOICE_ID, VALUE);
    }

    function test_Submit_RevertIfNotSubmitter() public {
        vm.prank(stranger);
        vm.expectRevert(InvoiceOracle.NotSubmitter.selector);
        oracle.submit(INVOICE_ID, VALUE);
    }

    function test_Submit_RevertIfValueIsZero() public {
        vm.prank(submitter);
        vm.expectRevert(InvoiceOracle.InvalidValue.selector);
        oracle.submit(INVOICE_ID, 0);
    }

    function test_Submit_RevertIfSubmissionAlreadyExists() public {
        vm.startPrank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.expectRevert(InvoiceOracle.SubmissionAlreadyActive.selector);
        oracle.submit(INVOICE_ID, VALUE);
        vm.stopPrank();
    }

    function test_Dispute_HappyPath() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(challenger);
        oracle.dispute(INVOICE_ID);

        (uint256 submittedValue, address recordedSubmitter,,, bool disputed, bool exists) =
            oracle.activeSubmissions(INVOICE_ID);

        assertTrue(exists);
        assertTrue(disputed);
        assertEq(submittedValue, VALUE);
        assertEq(recordedSubmitter, submitter);
    }

    function test_Dispute_EmitsSubmissionMarkedDisputed() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(challenger);
        vm.expectEmit(true, true, false, false);
        emit InvoiceOracle.SubmissionMarkedDisputed(INVOICE_ID, challenger);

        oracle.dispute(INVOICE_ID);
    }

    function test_Dispute_RevertIfNotChallenger() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(stranger);
        vm.expectRevert(InvoiceOracle.NotChallenger.selector);
        oracle.dispute(INVOICE_ID);
    }

    function test_Dispute_RevertIfWindowExpired() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.warp(block.timestamp + DISPUTE_WINDOW + 1);

        vm.prank(challenger);
        vm.expectRevert(InvoiceOracle.DisputeWindowExpired.selector);
        oracle.dispute(INVOICE_ID);
    }

    function test_Dispute_RevertIfAlreadyDisputed() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(challenger);
        oracle.dispute(INVOICE_ID);

        vm.prank(challenger);
        vm.expectRevert(InvoiceOracle.SubmissionAlreadyDisputed.selector);
        oracle.dispute(INVOICE_ID);
    }

    function test_Finalize_HappyPath() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.warp(block.timestamp + DISPUTE_WINDOW);

        oracle.finalize(INVOICE_ID);

        (uint256 finalizedValueStored, uint64 finalizedAt, bool finalizedExists) = oracle.finalizedValues(INVOICE_ID);

        (
            uint256 submittedValue,
            address recordedSubmitter,
            uint64 submittedAt,
            uint64 disputeDeadline,
            bool disputed,
            bool exists
        ) = oracle.activeSubmissions(INVOICE_ID);

        assertTrue(finalizedExists);
        assertEq(finalizedValueStored, VALUE);
        assertEq(finalizedAt, block.timestamp);

        assertFalse(exists);
        assertEq(submittedValue, 0);
        assertEq(recordedSubmitter, address(0));
        assertEq(submittedAt, 0);
        assertEq(disputeDeadline, 0);
        assertFalse(disputed);
    }

    function test_Finalize_EmitsSubmissionFinalized() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.warp(block.timestamp + DISPUTE_WINDOW);

        vm.expectEmit(true, false, false, true);
        emit InvoiceOracle.SubmissionFinalized(INVOICE_ID, VALUE);

        oracle.finalize(INVOICE_ID);
    }

    function test_Finalize_RevertIfNotFound() public {
        vm.expectRevert(InvoiceOracle.SubmissionNotFound.selector);
        oracle.finalize(INVOICE_ID);
    }

    function test_Finalize_RevertIfDisputed() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(challenger);
        oracle.dispute(INVOICE_ID);

        vm.warp(block.timestamp + DISPUTE_WINDOW);

        vm.expectRevert(InvoiceOracle.SubmissionDisputed.selector);
        oracle.finalize(INVOICE_ID);
    }

    function test_Finalize_RevertIfWindowNotExpired() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.expectRevert(InvoiceOracle.DisputeWindowNotExpired.selector);
        oracle.finalize(INVOICE_ID);
    }

    function test_CancelDisputedSubmission_HappyPath() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(challenger);
        oracle.dispute(INVOICE_ID);

        vm.prank(owner);
        oracle.cancelDisputedSubmission(INVOICE_ID);

        (
            uint256 submittedValue,
            address recordedSubmitter,
            uint64 submittedAt,
            uint64 disputeDeadline,
            bool disputed,
            bool exists
        ) = oracle.activeSubmissions(INVOICE_ID);

        assertFalse(exists);
        assertEq(submittedValue, 0);
        assertEq(recordedSubmitter, address(0));
        assertEq(submittedAt, 0);
        assertEq(disputeDeadline, 0);
        assertFalse(disputed);
    }

    function test_CancelDisputedSubmission_EmitsSubmissionCancelled() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(challenger);
        oracle.dispute(INVOICE_ID);

        vm.prank(owner);
        vm.expectEmit(true, false, false, false);
        emit InvoiceOracle.SubmissionCancelled(INVOICE_ID);

        oracle.cancelDisputedSubmission(INVOICE_ID);
    }

    function test_CancelDisputedSubmission_RevertIfNotOwner() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(challenger);
        oracle.dispute(INVOICE_ID);

        vm.prank(stranger);
        vm.expectRevert(InvoiceOracle.NotOwner.selector);
        oracle.cancelDisputedSubmission(INVOICE_ID);
    }

    function test_CancelDisputedSubmission_RevertIfNotDisputed() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.prank(owner);
        vm.expectRevert(InvoiceOracle.SubmissionNotDisputed.selector);
        oracle.cancelDisputedSubmission(INVOICE_ID);
    }

    function test_GetFinalizedValue_HappyPath() public {
        vm.prank(submitter);
        oracle.submit(INVOICE_ID, VALUE);

        vm.warp(block.timestamp + DISPUTE_WINDOW);
        oracle.finalize(INVOICE_ID);

        uint256 finalizedValue = oracle.getFinalizedValue(INVOICE_ID);

        assertEq(finalizedValue, VALUE);
    }

    function test_GetFinalizedValue_RevertIfNotExists() public {
        vm.expectRevert(InvoiceOracle.NoFinalizedValue.selector);
        oracle.getFinalizedValue(INVOICE_ID);
    }

    function test_Submissions_AreIsolatedPerInvoiceId() public {
        vm.startPrank(submitter);
        oracle.submit(INVOICE_ID, VALUE);
        oracle.submit(INVOICE_ID_2, VALUE);
        vm.stopPrank();

        vm.warp(block.timestamp + DISPUTE_WINDOW);
        oracle.finalize(INVOICE_ID);

        uint256 finalizedValue = oracle.getFinalizedValue(INVOICE_ID);
        assertEq(finalizedValue, VALUE);

        (uint256 submittedValue2, address recordedSubmitter2,,, bool disputed2, bool exists2) =
            oracle.activeSubmissions(INVOICE_ID_2);

        assertTrue(exists2);
        assertFalse(disputed2);
        assertEq(submittedValue2, VALUE);
        assertEq(recordedSubmitter2, submitter);
    }
}
