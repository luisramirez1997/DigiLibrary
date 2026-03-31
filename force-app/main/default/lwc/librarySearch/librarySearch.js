/**
 * ─────────────────────────────────────────────────────────────────────────────
 * @component   librarySearch
 * @description Controller for the DigiLibrary book search LWC.
 *              Calls LibraryService imperatively to search books via SOSL
 *              and to register loan requests for a selected Contact borrower.
 *
 * @author      Luis Hernandez
 * @version     1.1
 * @date        2026-03-31
 * ─────────────────────────────────────────────────────────────────────────────
 */
import { LightningElement, track } from 'lwc';
import { ShowToastEvent }          from 'lightning/platformShowToastEvent';
import searchBooks                 from '@salesforce/apex/LibraryService.searchBooks';
import loanBook                    from '@salesforce/apex/LibraryService.loanBook';

export default class LibrarySearch extends LightningElement {

    // ─── State ───────────────────────────────────────────────────────────────

    @track books          = [];
    isLoading             = false;      // primitive — reactive by default, no @track needed
    searchTerm            = '';
    selectedBorrowerId    = null;       // Contact Id selected via the record picker
    _processingBookId     = null;       // tracks which book row is mid-request
    _hasSearched          = false;

    // ─── Getters ─────────────────────────────────────────────────────────────

    get hasResults() {
        return this.books.length > 0;
    }

    get noResults() {
        return this._hasSearched && !this.isLoading && this.books.length === 0;
    }

    // ─── Event Handlers ──────────────────────────────────────────────────────

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
    }

    handleKeyUp(event) {
        if (event.key === 'Enter') this.handleSearch();
    }

    /** Captures the Contact Id from the record picker */
    handleBorrowerChange(event) {
        this.selectedBorrowerId = event.detail.recordId;
        // § Re-annotate books so loan buttons reflect the new borrower selection
        this._annotatebooks(this.books);
    }

    /** Calls LibraryService.searchBooks and populates the results table */
    handleSearch() {
        if (!this.searchTerm.trim()) return;

        this.isLoading    = true;
        this._hasSearched = true;

        searchBooks({ searchTerm: this.searchTerm })
            .then(result => {
                this._annotatebooks(result);
            })
            .catch(error => {
                this.showToast('Error', this.extractError(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /** Calls LibraryService.loanBook for the selected book and borrower */
    handleLoanRequest(event) {
        const bookId = event.currentTarget.dataset.bookId;

        // § Guard: a borrower Contact must be selected before requesting a loan
        if (!this.selectedBorrowerId) {
            this.showToast('Missing Borrower', 'Please select a borrower contact first.', 'warning');
            return;
        }

        // § Disable this specific row's button while the request is in flight
        this._processingBookId = bookId;
        this._annotatebooks(this.books);

        loanBook({ bookId, borrowerId: this.selectedBorrowerId })
            .then(() => {
                this.showToast('Success', 'Loan registered successfully!', 'success');
                this._processingBookId = null;
                // § Refresh so availability count updates immediately in the table
                this.handleSearch();
            })
            .catch(error => {
                this.showToast('Error', this.extractError(error), 'error');
                this._processingBookId = null;
                this._annotatebooks(this.books);
            });
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    /**
     * @description Adds computed UI properties to each book record:
     *              - availabilityBadge : SLDS badge class (green / red)
     *              - loanButtonLabel   : reflects processing state
     *              - loanButtonDisabled: true when unavailable, processing, or no borrower
     */
    _annotatebooks(rawBooks) {
        this.books = rawBooks.map(book => ({
            ...book,
            availabilityBadge  : book.Available_Copies__c > 0
                ? 'slds-badge slds-theme_success'
                : 'slds-badge slds-theme_error',
            loanButtonLabel    : this._processingBookId === book.Id
                ? 'Processing...'
                : 'Request Loan',
            loanButtonDisabled : book.Available_Copies__c <= 0
                || !this.selectedBorrowerId
                || this._processingBookId === book.Id
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (error?.body?.message) return error.body.message;
        return 'An unexpected error occurred.';
    }
}
