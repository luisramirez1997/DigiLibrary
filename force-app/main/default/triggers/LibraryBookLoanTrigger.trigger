/**
 * ─────────────────────────────────────────────────────────────────────────────
 * @trigger     LibraryBookLoanTrigger
 * @description Trigger on Library_Book_Loan__c that delegates all logic to
 *              LibraryBookLoanTriggerHandler, keeping this file thin and
 *              the business logic testable in isolation.
 *
 * @author      Luis Hernandez
 * @version     1.0
 * @date        2026-03-31
 * ─────────────────────────────────────────────────────────────────────────────
 */
trigger LibraryBookLoanTrigger on Library_Book_Loan__c (before insert, after insert, after delete) {

    if (Trigger.isBefore && Trigger.isInsert) {
        LibraryBookLoanTriggerHandler.beforeInsert(Trigger.new);

    } else if (Trigger.isAfter && Trigger.isInsert) {
        LibraryBookLoanTriggerHandler.afterInsert(Trigger.new);

    } else if (Trigger.isAfter && Trigger.isDelete) {
        LibraryBookLoanTriggerHandler.afterDelete(Trigger.old);
    }
}
