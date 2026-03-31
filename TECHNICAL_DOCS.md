# DigiLibrary — Technical Documentation

**Author:** Luis Hernandez  
**API Version:** 66.0  
**Platform:** Salesforce Lightning  
**Last Updated:** 2026-03-31

---

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Data Model](#3-data-model)
4. [Apex Classes](#4-apex-classes)
5. [Apex Trigger](#5-apex-trigger)
6. [Lightning Web Component](#6-lightning-web-component)
7. [Unit Tests](#7-unit-tests)
8. [Permission Set](#8-permission-set)
9. [Deployment Guide](#9-deployment-guide)
10. [Known Limitations & Future Improvements](#10-known-limitations--future-improvements)

---

## 1. Overview

DigiLibrary is a corporate digital library management system built on Salesforce. It allows employees to:

- Search for books by title or author using full-text SOSL search
- View real-time availability (available vs. total copies)
- Request a book loan linked to a Contact (borrower)
- Automatically track inventory — copies decrement on loan, increment on return (delete)

The app is accessible via the **DigiLibrary** Lightning App and is governed by the `DigiLibrary_APP` permission set.

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Lightning App (UI)                      │
│                  DigiLibrary — Book Search                  │
│                   librarySearch (LWC)                       │
└───────────────────────┬─────────────────────────────────────┘
                        │ @AuraEnabled (imperative)
┌───────────────────────▼─────────────────────────────────────┐
│                   LibraryService.cls                        │
│   searchBooks()  ────── SOSL ──────► Library_Book__c        │
│   loanBook()     ────── DML  ──────► Library_Book_Loan__c   │
└───────────────────────┬─────────────────────────────────────┘
                        │ insert / delete
┌───────────────────────▼─────────────────────────────────────┐
│           LibraryBookLoanTrigger (thin trigger)             │
│                        │                                    │
│         LibraryBookLoanTriggerHandler.cls                   │
│   beforeInsert()  — validates Available_Copies__c > 0       │
│   afterInsert()   — decrements Available_Copies__c          │
│   afterDelete()   — increments Available_Copies__c          │
└─────────────────────────────────────────────────────────────┘
```

### Design Decisions

| Decision | Rationale |
|---|---|
| Thin trigger + handler class | Business logic is testable in isolation; trigger stays clean |
| `with sharing` on all classes | Enforces record-level security (OWD/sharing rules) |
| SOSL instead of SOQL for search | Searches across multiple fields in one query; more performant for text lookups |
| Double validation (service + trigger) | Service provides a meaningful exception for LWC; trigger is the database-level safety net |
| Bulk-safe DML pattern | All queries/DML outside loops; passes 200-record governor limit tests |

---

## 3. Data Model

### `Library_Book__c`

| Field API Name | Label | Type | Description |
|---|---|---|---|
| `Name` | Library Book Name | Text (auto) | Standard name field |
| `Tittle__c` | Title | Text | Book title |
| `Author__c` | Author | Text | Author name |
| `Available_Copies__c` | Available Copies | Number | Copies currently available for loan |
| `Total_Copies__c` | Total Copies | Number | Total copies owned by the library |



**Sharing Model:** ReadWrite  
**Search Enabled:** Yes

---

### `Library_Book_Loan__c`

| Field API Name | Label | Type | Description |
|---|---|---|---|
| `Name` | Library Book Loan Name | Text (auto) | Standard name field |
| `Book__c` | Book | Lookup (Library_Book__c) | The book being borrowed |
| `Borrower__c` | Borrower | Lookup (Contact) | The employee borrowing the book |
| `Loan_Start_Date__c` | Loan Start Date | Date | Date the loan was registered |
| `Loan_End_Date__c` | Loan End Date | Date | Expected return date |

**Sharing Model:** ReadWrite  
**Trigger:** `LibraryBookLoanTrigger` (before insert, after insert, after delete)

---

### Relationship Diagram

```
Contact (standard)
    │
    │ Borrower__c (Lookup)
    ▼
Library_Book_Loan__c ──── Book__c (Lookup) ────► Library_Book__c
```

---

## 4. Apex Classes

---

### `NoAvailableCopiesException`

**File:** `classes/NoAvailableCopiesException.cls`  
**Type:** Custom Exception

```apex
public class NoAvailableCopiesException extends Exception {}
```

Extends the base `Exception` class. By inheriting from `Exception`, it automatically provides:
- `new NoAvailableCopiesException('message')` constructor
- `getMessage()`, `getStackTraceString()`, etc.

**When thrown:**
- `LibraryService.loanBook()` — when `Available_Copies__c <= 0` or book not found

---

### `LibraryBookLoanTriggerHandler`

**File:** `classes/LibraryBookLoanTriggerHandler.cls`  
**Access:** `public with sharing`

Handles all business logic for `Library_Book_Loan__c` trigger events. Designed to be bulk-safe (never queries or does DML inside a loop).

#### Methods

---

##### `beforeInsert(List<Library_Book_Loan__c> newLoans)`

Validates that each incoming loan has at least one available copy of the requested book.

**Flow:**
1. Collects all unique `Book__c` Ids from `newLoans`
2. Queries `Available_Copies__c` for those books in **one SOQL**
3. Iterates loans — calls `loan.addError()` if `Available_Copies__c <= 0` or book not found

**Error behavior:** Adds error to the record (not the field), which surfaces as a banner in the UI and blocks the DML for that specific record without affecting valid records in the batch.

---

##### `afterInsert(List<Library_Book_Loan__c> newLoans)`

Decrements `Available_Copies__c` for each book affected by new loans.

**Flow:**
1. Counts loans per `Book__c` Id → `Map<Id, Integer> loanCountByBook`
2. Queries affected books in **one SOQL**
3. Decrements `Available_Copies__c` by the count per book
4. Updates all books in **one DML**

---

##### `afterDelete(List<Library_Book_Loan__c> oldLoans)`

Increments `Available_Copies__c` when loans are deleted (book returned).

**Flow:** Same pattern as `afterInsert` but increments instead of decrements.

---

### `LibraryService`

**File:** `classes/LibraryService.cls`  
**Access:** `public with sharing`

Service class exposing `@AuraEnabled` methods for the LWC.

#### Methods

---

##### `searchBooks(String searchTerm) → List<Library_Book__c>`

**Annotation:** `@AuraEnabled(cacheable=true)`

Searches books by title or author using SOSL.

| Parameter | Type | Description |
|---|---|---|
| `searchTerm` | String | Text to search across all indexed fields |

**Returns:** `List<Library_Book__c>` with fields: `Id, Name, Tittle__c, Author__c, Available_Copies__c, Total_Copies__c`

**Behavior:**
- Returns empty list immediately if `searchTerm` is blank
- Uses `IN ALL FIELDS` SOSL scope — searches title, author, and name simultaneously

---

##### `loanBook(Id bookId, Id borrowerId)`

**Annotation:** `@AuraEnabled`

Registers a new loan record for the given book and borrower.

| Parameter | Type | Description |
|---|---|---|
| `bookId` | Id | `Library_Book__c` record Id |
| `borrowerId` | Id | `Contact` record Id |

**Throws:** `NoAvailableCopiesException` if:
- Book record not found (`bookId` doesn't exist)
- `Available_Copies__c <= 0`

**Note:** Inventory decrement is handled by the trigger (`afterInsert`), not by this method directly.

---

## 5. Apex Trigger

### `LibraryBookLoanTrigger`

**File:** `triggers/LibraryBookLoanTrigger.trigger`  
**Object:** `Library_Book_Loan__c`  
**Events:** `before insert`, `after insert`, `after delete`

Thin trigger — contains no business logic. All logic is delegated to `LibraryBookLoanTriggerHandler`.

```apex
trigger LibraryBookLoanTrigger on Library_Book_Loan__c (before insert, after insert, after delete) {
    if (Trigger.isBefore && Trigger.isInsert)       LibraryBookLoanTriggerHandler.beforeInsert(Trigger.new);
    else if (Trigger.isAfter && Trigger.isInsert)   LibraryBookLoanTriggerHandler.afterInsert(Trigger.new);
    else if (Trigger.isAfter && Trigger.isDelete)   LibraryBookLoanTriggerHandler.afterDelete(Trigger.old);
}
```

### Trigger Execution Flow

```
User clicks "Request Loan" in LWC
        │
        ▼
LibraryService.loanBook()
  ├── Queries book (1 SOQL)
  ├── Throws NoAvailableCopiesException if 0 copies
  └── insert Library_Book_Loan__c
            │
            ▼
    BEFORE INSERT
    LibraryBookLoanTriggerHandler.beforeInsert()
      ├── 1 SOQL: fetch books by Id
      └── addError() if no copies → DML blocked
            │
            ▼ (if no errors)
    AFTER INSERT
    LibraryBookLoanTriggerHandler.afterInsert()
      ├── 1 SOQL: fetch books
      ├── Decrement Available_Copies__c
      └── 1 DML: update books
```

---

## 6. Lightning Web Component

### `librarySearch`

**Files:**
- `lwc/librarySearch/librarySearch.html`
- `lwc/librarySearch/librarySearch.js`
- `lwc/librarySearch/librarySearch.js-meta.xml`

**Exposed to:** App pages (Lightning App Builder)  
**API Version:** 66.0

---

### Component State

| Property | Type | Description |
|---|---|---|
| `books` | `Array` (`@track`) | Annotated book records for the results table |
| `isLoading` | `Boolean` | Controls the loading spinner |
| `searchTerm` | `String` | Bound to the search input |
| `selectedBorrowerId` | `Id` | Contact Id from the record picker |
| `_processingBookId` | `Id` | Tracks the book row mid-loan-request |
| `_hasSearched` | `Boolean` | Tracks whether a search has been executed |

---

### Computed Getters

| Getter | Returns | Description |
|---|---|---|
| `hasResults` | `Boolean` | `books.length > 0` |
| `noResults` | `Boolean` | Searched, not loading, and no books found |

---

### Key Methods

#### `handleSearch()`
Calls `LibraryService.searchBooks` imperatively. On success, passes result through `_annotatebooks()` before storing in `this.books`.

#### `handleLoanRequest(event)`
Reads `data-book-id` from the button dataset. Guards against missing borrower selection. Sets `_processingBookId` to disable the button row during the request. On success, **fully resets state**: clears `searchTerm`, `selectedBorrowerId`, `books`, `_hasSearched`, and the DOM input/picker values.

#### `_annotatebooks(rawBooks)`
Adds computed UI properties to each book record before storing in state:

| Property | Description |
|---|---|
| `isUnavailable` | `Available_Copies__c <= 0` |
| `availabilityBadge` | SLDS class: `slds-theme_success` or `slds-theme_error` |
| `loanButtonLabel` | `'Processing...'` when in-flight, otherwise `'Request Loan'` |
| `loanButtonDisabled` | `true` if no borrower selected or this row is processing |

---

### Template Structure

```
lightning-card
└── slds-p-around_medium
    ├── lightning-layout (search bar + button)
    ├── lightning-record-picker (borrower selector)
    ├── [lwc:if isLoading] lightning-spinner
    ├── [lwc:if noResults] "No books found" message
    └── [lwc:if hasResults] slds-table
        └── for:each books
            ├── Title, Author, Available (badge), Total
            └── [lwc:if isUnavailable] "⚠ No copies available"
                [lwc:else] lightning-button "Request Loan"
```

---

## 7. Unit Tests

### `LibraryBookLoanTriggerTest`

**Coverage target:** Trigger + Handler  
**Tests:** 5

| Test | Scenario | Expected |
|---|---|---|
| `testInsert_decrementsCopies` | Insert 1 loan on book with 3 copies | `Available_Copies__c = 2` |
| `testInsert_blockedWhenNoCopies` | Insert loan on book with 0 copies | `DmlException` thrown |
| `testDelete_incrementsCopies` | Delete an existing loan | `Available_Copies__c` restored |
| `testBulkInsert_200Loans` | Insert 200 loans across 200 books | Each book has 4 copies remaining |
| `testBulkDelete_200Loans` | Delete 200 loans | Each book restored to 5 copies |

---

### `LibraryServiceTest`

**Coverage target:** `LibraryService`  
**Tests:** 6

| Test | Scenario | Expected |
|---|---|---|
| `testSearchBooks_found` | Valid search term with matching book | Returns 1 book |
| `testSearchBooks_blankTerm` | Blank/whitespace search term | Returns empty list |
| `testSearchBooks_noResults` | No matching books | Returns empty list |
| `testLoanBook_success` | Valid book + borrower | Loan record created, copies decremented |
| `testLoanBook_noCopies` | Book with 0 copies | `NoAvailableCopiesException` thrown |
| `testLoanBook_bookNotFound` | Deleted book Id | `NoAvailableCopiesException` thrown |

> **Note:** SOSL tests require `Test.setFixedSearchResults()` — SOSL always returns empty in test context without it.

---

## 8. Permission Set

### `DigiLibrary_APP`

Assign this permission set to any user who needs access to the DigiLibrary app.

| Permission Type | Target | Access |
|---|---|---|
| App Visibility | `DigiLibrary` | Visible |
| Object | `Library_Book__c` | Read, Create, Edit, Delete, View All, Modify All |
| Object | `Library_Book_Loan__c` | Read, Create, Edit, Delete, View All, Modify All |
| Object | `Contact` | Read only |
| Fields | All fields on both objects | Read + Edit |
| Apex Class | `LibraryService` | Enabled |
| Apex Class | `LibraryBookLoanTriggerHandler` | Enabled |
| Apex Class | `NoAvailableCopiesException` | Enabled |
| Tab | `Library_Book__c` | Visible |
| Tab | `Library_Book_Loan__c` | Visible |

> **Contact read** is required for the `lightning-record-picker` in the LWC to resolve Contact records.

---

## 9. Deployment Guide

### Prerequisites

- Salesforce CLI (`sf`) installed
- VS Code + Salesforce Extension Pack
- Authorized org (sandbox or scratch org recommended)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/luisramirez1997/DigiLibrary.git
cd DigiLibrary

# 2. Authorize your org
sf org login web --alias myOrg

# 3. Deploy all metadata
sf project deploy start --source-dir force-app --target-org myOrg

# 4. Run all tests and verify coverage
sf apex run test --test-level RunLocalTests --wait 10 --target-org myOrg

# 5. Assign the permission set to your user
sf org assign permset --name DigiLibrary_APP --target-org myOrg
```

### Post-Deployment Steps (manual)

1. Go to **App Builder** → find or create the **DigiLibrary** Lightning App
2. Add the `librarySearch` LWC component to an app page
3. Activate and assign the page
4. Create sample `Library_Book__c` records and `Contact` records for testing

---

## 10. Known Limitations & Future Improvements

| Area | Current State | Suggested Improvement |
|---|---|---|
| Concurrency | Two users can pass `beforeInsert` simultaneously on the same book, potentially going below 0 copies | Add a floor check in `afterInsert` or use a select-for-update pattern |
| Loan return | Loans are "returned" by deleting the record | Add a `Status__c` field (Active/Returned) and handle returns via update trigger instead of delete |
| `Loan_End_Date__c` | Field exists but is never set during loan creation | Set a default return date in `LibraryService.loanBook()` (e.g., `Date.today().addDays(14)`) |
| LWC error handling | `extractError` only reads `error.body.message` | Also handle `error.body.output.errors` for field-level Apex errors |
| Search refresh after error | On loan error, the book list is not refreshed | Re-call `searchBooks` in the catch block to reflect any server-side changes |
| Test setup | Tests use private factory methods per test | Migrate to `@TestSetup` for shared test data — more efficient and idiomatic |
| `@wire` vs imperative | `searchBooks` is `cacheable=true` but called imperatively | Consider `@wire` for the initial/auto search if the UX allows it |
