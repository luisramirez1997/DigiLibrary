/**
 * ─────────────────────────────────────────────────────────────────────────────
 * @class       LibraryServiceTest
 * @description Unit tests for LibraryService. Covers SOSL book search
 *              (found, not found, blank term) and loan registration
 *              (success, no copies available, book not found).
 *
 * @author      Luis Hernandez
 * @version     1.0
 * @date        2026-03-31
 * ─────────────────────────────────────────────────────────────────────────────
 */
@isTest
private class LibraryServiceTest {

    // ─── Test Data Factories ─────────────────────────────────────────────────

    private static Library_Book__c createBook(String title, String author, Integer available) {
        Library_Book__c book = new Library_Book__c(
            Tittle__c           = title,
            Author__c           = author,
            Available_Copies__c = available,
            Total_Copies__c     = available
        );
        insert book;
        return book;
    }

    private static Contact createContact() {
        Contact c = new Contact(LastName = 'ServiceTestBorrower');
        insert c;
        return c;
    }

    // ─── searchBooks ─────────────────────────────────────────────────────────

    /**
     * @description SOSL with a matching term should return at least one book.
     *              SOSL in tests requires Test.setFixedSearchResults().
     */
    @isTest
    static void testSearchBooks_found() {
        Library_Book__c book = createBook('El Principito', 'Saint-Exupery', 3);

        // § Salesforce requires this in tests — SOSL always returns empty otherwise
        Test.setFixedSearchResults(new List<Id>{ book.Id });

        Test.startTest();
        List<Library_Book__c> results = LibraryService.searchBooks('El Principito');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one matching book');
        System.assertEquals(book.Id, results[0].Id, 'Returned book Id should match');
    }

    /**
     * @description A blank search term should return an empty list immediately.
     */
    @isTest
    static void testSearchBooks_blankTerm() {
        Test.startTest();
        List<Library_Book__c> results = LibraryService.searchBooks('   ');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Blank term should return empty list');
    }

    /**
     * @description A term with no matching books should return an empty list.
     */
    @isTest
    static void testSearchBooks_noResults() {
        Test.setFixedSearchResults(new List<Id>());

        Test.startTest();
        List<Library_Book__c> results = LibraryService.searchBooks('ZZZ_NO_MATCH_XYZ');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Non-matching term should return empty list');
    }

    // ─── loanBook ────────────────────────────────────────────────────────────

    /**
     * @description A valid loan request should create a loan record and
     *              the trigger should decrement Available_Copies__c.
     */
    @isTest
    static void testLoanBook_success() {
        Library_Book__c book     = createBook('Clean Code', 'Robert Martin', 2);
        Contact         borrower = createContact();

        Test.startTest();
        LibraryService.loanBook(book.Id, borrower.Id);
        Test.stopTest();

        List<Library_Book_Loan__c> loans = [
            SELECT Id FROM Library_Book_Loan__c
            WHERE Book__c = :book.Id AND Borrower__c = :borrower.Id
        ];
        System.assertEquals(1, loans.size(), 'One loan record should have been created');

        Library_Book__c updated = [SELECT Available_Copies__c FROM Library_Book__c WHERE Id = :book.Id];
        System.assertEquals(1, updated.Available_Copies__c, 'Available copies should decrease by 1');
    }

    /**
     * @description loanBook should throw NoAvailableCopiesException when
     *              Available_Copies__c is 0.
     */
    @isTest
    static void testLoanBook_noCopies() {
        Library_Book__c book     = createBook('No Copies Book', 'Author X', 0);
        Contact         borrower = createContact();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            LibraryService.loanBook(book.Id, borrower.Id);
        } catch (NoAvailableCopiesException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'NoAvailableCopiesException should be thrown when no copies are available');
    }

    /**
     * @description loanBook should throw NoAvailableCopiesException when
     *              the book Id does not exist.
     */
    @isTest
    static void testLoanBook_bookNotFound() {
        Contact borrower = createContact();

        // § Insert and delete a book to get a valid but non-existent Id
        Library_Book__c dummy = new Library_Book__c(
            Tittle__c = 'Dummy', Author__c = 'Dummy',
            Available_Copies__c = 1, Total_Copies__c = 1
        );
        insert dummy;
        Id deletedId = dummy.Id;
        delete dummy;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            LibraryService.loanBook(deletedId, borrower.Id);
        } catch (NoAvailableCopiesException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'NoAvailableCopiesException should be thrown when book is not found');
    }
}
