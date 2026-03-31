/**
 * ─────────────────────────────────────────────────────────────────────────────
 * @class       LibraryService
 * @description Service class that exposes book search and loan registration
 *              functionality to both Apex consumers and Lightning components.
 *              Throws NoAvailableCopiesException when a loan cannot be created
 *              due to insufficient inventory.
 *
 * @author      Luis Hernandez
 * @version     1.0
 * @date        2026-03-31
 * ─────────────────────────────────────────────────────────────────────────────
 */
public with sharing class LibraryService {

    // ─── SEARCH ──────────────────────────────────────────────────────────────

    /**
     * @description Searches for books by title or author using SOSL.
     *              Returns an empty list if the search term is blank.
     *              Marked cacheable so LWC can wire it for read-only calls.
     *
     * @param       searchTerm  The text to search across Tittle__c and Author__c
     * @return      List of matching Library_Book__c records
     */
    @AuraEnabled(cacheable=true)
    public static List<Library_Book__c> searchBooks(String searchTerm) {

        // § 1 — Guard against blank input
        if (String.isBlank(searchTerm)) {
            return new List<Library_Book__c>();
        }

        // § 2 — SOSL searches across both title and author fields in one call
        List<List<SObject>> searchResults = [
            FIND :searchTerm
            IN ALL FIELDS
            RETURNING Library_Book__c(Id, Name, Tittle__c, Author__c, Available_Copies__c, Total_Copies__c)
        ];

        return (List<Library_Book__c>) searchResults[0];
    }

    // ─── LOAN ────────────────────────────────────────────────────────────────

    /**
     * @description Registers a loan for a given book and borrower.
     *              Validates availability before inserting — the trigger will
     *              also enforce this, but we throw the custom exception here
     *              so the LWC can surface a meaningful error message.
     *
     * @param       bookId      Id of the Library_Book__c to borrow
     * @param       borrowerId  Id of the Contact borrowing the book
     * @throws      NoAvailableCopiesException if no copies are available
     */
    @AuraEnabled
    public static void loanBook(Id bookId, Id borrowerId) {

        // § 1 — Fetch the book in a single optimized SOQL query
        List<Library_Book__c> books = [
            SELECT Id, Available_Copies__c
            FROM   Library_Book__c
            WHERE  Id = :bookId
            LIMIT  1
        ];

        // § 2 — Validate the book exists
        if (books.isEmpty()) {
            throw new NoAvailableCopiesException('Book not found.');
        }

        // § 3 — Validate available copies
        Library_Book__c book = books[0];
        if (book.Available_Copies__c <= 0) {
            throw new NoAvailableCopiesException('No available copies for this book.');
        }

        // § 4 — Create the loan record (trigger handles the inventory decrement)
        Library_Book_Loan__c loan = new Library_Book_Loan__c(
            Book__c           = bookId,
            Borrower__c       = borrowerId,
            Loan_Start_Date__c = Date.today()
        );
        insert loan;
    }
}
