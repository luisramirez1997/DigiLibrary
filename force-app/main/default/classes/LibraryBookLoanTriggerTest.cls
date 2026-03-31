/**
 * ─────────────────────────────────────────────────────────────────────────────
 * @class       LibraryBookLoanTriggerTest
 * @description Unit tests for LibraryBookLoanTrigger and
 *              LibraryBookLoanTriggerHandler. Covers availability validation,
 *              copy decrement on insert, copy increment on delete, and bulk
 *              safety with 200 records.
 *
 * @author      Luis Hernandez
 * @version     1.0
 * @date        2026-03-31
 * ─────────────────────────────────────────────────────────────────────────────
 */
@isTest
private class LibraryBookLoanTriggerTest {

    // ─── Test Data Factories ─────────────────────────────────────────────────

    /**
     * @description Creates and inserts a Library_Book__c with the given copy counts.
     */
    private static Library_Book__c createBook(Integer available, Integer total) {
        Library_Book__c book = new Library_Book__c(
            Tittle__c             = 'Test Book',
            Author__c             = 'Test Author',
            Available_Copies__c   = available,
            Total_Copies__c       = total
        );
        insert book;
        return book;
    }

    /**
     * @description Creates and inserts a Contact to act as borrower.
     */
    private static Contact createContact() {
        Contact c = new Contact(LastName = 'TestBorrower');
        insert c;
        return c;
    }

    /**
     * @description Builds a loan record without inserting it.
     */
    private static Library_Book_Loan__c buildLoan(Id bookId, Id contactId) {
        return new Library_Book_Loan__c(
            Book__c            = bookId,
            Borrower__c        = contactId,
            Loan_Start_Date__c = Date.today()
        );
    }

    // ─── Tests ───────────────────────────────────────────────────────────────

    /**
     * @description Inserting a loan should decrement Available_Copies__c by 1.
     */
    @isTest
    static void testInsert_decrementsCopies() {
        Library_Book__c book     = createBook(3, 3);
        Contact         borrower = createContact();

        Test.startTest();
        insert buildLoan(book.Id, borrower.Id);
        Test.stopTest();

        Library_Book__c result = [SELECT Available_Copies__c FROM Library_Book__c WHERE Id = :book.Id];
        System.assertEquals(2, result.Available_Copies__c, 'Available copies should decrease by 1 after insert');
    }

    /**
     * @description Inserting a loan for a book with 0 copies should be blocked.
     */
    @isTest
    static void testInsert_blockedWhenNoCopies() {
        Library_Book__c book     = createBook(0, 5);
        Contact         borrower = createContact();

        Test.startTest();
        Boolean wasBlocked = false;
        try {
            insert buildLoan(book.Id, borrower.Id);
        } catch (DmlException e) {
            wasBlocked = true;
        }
        Test.stopTest();

        System.assert(wasBlocked, 'Insert should be blocked when Available_Copies__c is 0');
    }

    /**
     * @description Deleting a loan should increment Available_Copies__c by 1.
     */
    @isTest
    static void testDelete_incrementsCopies() {
        Library_Book__c         book     = createBook(2, 3);
        Contact                 borrower = createContact();
        Library_Book_Loan__c    loan     = buildLoan(book.Id, borrower.Id);
        insert loan;

        Test.startTest();
        delete loan;
        Test.stopTest();

        Library_Book__c result = [SELECT Available_Copies__c FROM Library_Book__c WHERE Id = :book.Id];
        System.assertEquals(2, result.Available_Copies__c, 'Available copies should be restored after delete');
    }

    /**
     * @description Bulk insert of 200 loans across 200 books should complete
     *              in a single transaction without hitting governor limits.
     */
    @isTest
    static void testBulkInsert_200Loans() {
        Contact borrower = createContact();

        // § Create 200 books each with 5 available copies
        List<Library_Book__c> books = new List<Library_Book__c>();
        for (Integer i = 0; i < 200; i++) {
            books.add(new Library_Book__c(
                Tittle__c           = 'Book ' + i,
                Author__c           = 'Author ' + i,
                Available_Copies__c = 5,
                Total_Copies__c     = 5
            ));
        }
        insert books;

        // § Build one loan per book
        List<Library_Book_Loan__c> loans = new List<Library_Book_Loan__c>();
        for (Library_Book__c b : books) {
            loans.add(buildLoan(b.Id, borrower.Id));
        }

        Test.startTest();
        insert loans;
        Test.stopTest();

        // § Every book should now have 4 available copies
        List<Library_Book__c> updated = [
            SELECT Available_Copies__c
            FROM   Library_Book__c
            WHERE  Id IN :new Map<Id, Library_Book__c>(books).keySet()
        ];
        for (Library_Book__c b : updated) {
            System.assertEquals(4, b.Available_Copies__c, 'Each book should have 4 copies after bulk insert');
        }
    }

    /**
     * @description Bulk delete of 200 loans should restore all copy counts.
     */
    @isTest
    static void testBulkDelete_200Loans() {
        Contact borrower = createContact();

        List<Library_Book__c> books = new List<Library_Book__c>();
        for (Integer i = 0; i < 200; i++) {
            books.add(new Library_Book__c(
                Tittle__c           = 'Book ' + i,
                Author__c           = 'Author ' + i,
                Available_Copies__c = 5,
                Total_Copies__c     = 5
            ));
        }
        insert books;

        List<Library_Book_Loan__c> loans = new List<Library_Book_Loan__c>();
        for (Library_Book__c b : books) {
            loans.add(buildLoan(b.Id, borrower.Id));
        }
        insert loans;

        Test.startTest();
        delete loans;
        Test.stopTest();

        List<Library_Book__c> updated = [
            SELECT Available_Copies__c
            FROM   Library_Book__c
            WHERE  Id IN :new Map<Id, Library_Book__c>(books).keySet()
        ];
        for (Library_Book__c b : updated) {
            System.assertEquals(5, b.Available_Copies__c, 'Each book should have 5 copies restored after bulk delete');
        }
    }
}
