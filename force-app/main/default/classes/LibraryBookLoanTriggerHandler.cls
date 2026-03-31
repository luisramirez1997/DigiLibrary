/**
 * ─────────────────────────────────────────────────────────────────────────────
 * @class       LibraryBookLoanTriggerHandler
 * @description Handles all trigger logic for the Library_Book_Loan__c object.
 *              Validates book availability before a loan is created, and keeps
 *              the Available_Copies__c counter in sync whenever loans are
 *              inserted or deleted.
 *
 * @author      Luis Hernandez
 * @version     1.0
 * @date        2026-03-31
 * ─────────────────────────────────────────────────────────────────────────────
 */
public with sharing class LibraryBookLoanTriggerHandler {

    // ─── BEFORE INSERT ───────────────────────────────────────────────────────

    /**
     * @description Runs before a loan record is inserted.
     *              Queries all related books in one SOQL call (bulk-safe) and
     *              blocks the insert if a book has no available copies.
     *
     * @param       newLoans  List of incoming Library_Book_Loan__c records
     */
    public static void beforeInsert(List<Library_Book_Loan__c> newLoans) {

        // § 1 — Collect every unique Book Id from the incoming loans
        Set<Id> bookIds = new Set<Id>();
        for (Library_Book_Loan__c loan : newLoans) {
            if (loan.Book__c != null) {
                bookIds.add(loan.Book__c);
            }
        }

        // § 2 — Fetch those books in a single SOQL query (governor-limit safe)
        Map<Id, Library_Book__c> bookMap = new Map<Id, Library_Book__c>(
            [SELECT Id, Available_Copies__c
             FROM   Library_Book__c
             WHERE  Id IN :bookIds]
        );

        // § 3 — Validate each loan against its book's available copies
        for (Library_Book_Loan__c loan : newLoans) {
            Library_Book__c book = bookMap.get(loan.Book__c);

            if (book == null || book.Available_Copies__c <= 0) {
                // Attaching the error to the record surfaces it in both UI and API
                loan.addError('No available copies for this book.');
            }
        }
    }

    // ─── AFTER INSERT ────────────────────────────────────────────────────────

    /**
     * @description Runs after loan records are successfully inserted.
     *              Decrements Available_Copies__c by the number of loans
     *              created per book (handles bulk inserts correctly).
     *
     * @param       newLoans  List of newly inserted Library_Book_Loan__c records
     */
    public static void afterInsert(List<Library_Book_Loan__c> newLoans) {

        // § 1 — Count how many loans were created per book
        Map<Id, Integer> loanCountByBook = new Map<Id, Integer>();
        for (Library_Book_Loan__c loan : newLoans) {
            if (loan.Book__c != null) {
                Integer current = loanCountByBook.containsKey(loan.Book__c)
                    ? loanCountByBook.get(loan.Book__c) : 0;
                loanCountByBook.put(loan.Book__c, current + 1);
            }
        }

        // § 2 — Fetch the affected books in one SOQL query
        List<Library_Book__c> booksToUpdate = [
            SELECT Id, Available_Copies__c
            FROM   Library_Book__c
            WHERE  Id IN :loanCountByBook.keySet()
        ];

        // § 3 — Reduce each book's available copies by the loan count
        for (Library_Book__c book : booksToUpdate) {
            book.Available_Copies__c -= loanCountByBook.get(book.Id);
        }

        // § 4 — Persist all changes in a single DML statement
        update booksToUpdate;
    }

    // ─── AFTER DELETE ────────────────────────────────────────────────────────

    /**
     * @description Runs after loan records are deleted.
     *              Increments Available_Copies__c, effectively returning the
     *              book copies back to the inventory.
     *
     * @param       oldLoans  List of deleted Library_Book_Loan__c records
     */
    public static void afterDelete(List<Library_Book_Loan__c> oldLoans) {

        // § 1 — Count how many loans were removed per book
        Map<Id, Integer> returnCountByBook = new Map<Id, Integer>();
        for (Library_Book_Loan__c loan : oldLoans) {
            if (loan.Book__c != null) {
                Integer current = returnCountByBook.containsKey(loan.Book__c)
                    ? returnCountByBook.get(loan.Book__c) : 0;
                returnCountByBook.put(loan.Book__c, current + 1);
            }
        }

        // § 2 — Fetch the affected books in one SOQL query
        List<Library_Book__c> booksToUpdate = [
            SELECT Id, Available_Copies__c
            FROM   Library_Book__c
            WHERE  Id IN :returnCountByBook.keySet()
        ];

        // § 3 — Restore each book's available copies by the return count
        for (Library_Book__c book : booksToUpdate) {
            book.Available_Copies__c += returnCountByBook.get(book.Id);
        }

        // § 4 — Persist all changes in a single DML statement
        update booksToUpdate;
    }
}
