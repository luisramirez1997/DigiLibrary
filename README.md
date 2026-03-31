# DigiLibrary — Salesforce Corporate Digital Library

A Salesforce DX project that implements a corporate digital library system, built as a technical challenge. It allows employees to search for books and request loans directly from a Lightning Web Component.

---

## Features

- Book search using **SOSL** across title and author fields
- Loan registration with real-time **inventory management**
- Automatic decrement/increment of available copies via **Apex Trigger**
- Custom exception `NoAvailableCopiesException` for business rule enforcement
- Contact-based borrower selection using `lightning-record-picker`
- Visual availability badges (green/red) per book
- Full state reset after a successful loan request
- **85%+ test coverage** across all Apex classes

---

## Project Structure

```
force-app/main/default/
├── classes/
│   ├── NoAvailableCopiesException.cls        # Custom exception
│   ├── LibraryBookLoanTriggerHandler.cls     # Trigger logic (bulk-safe)
│   ├── LibraryService.cls                    # @AuraEnabled service class
│   ├── LibraryBookLoanTriggerTest.cls        # Trigger unit tests (5 tests)
│   └── LibraryServiceTest.cls               # Service unit tests (6 tests)
├── triggers/
│   └── LibraryBookLoanTrigger.trigger        # Thin trigger delegating to handler
├── lwc/
│   └── librarySearch/                        # Lightning Web Component
│       ├── librarySearch.html
│       └── librarySearch.js
├── objects/
│   ├── Library_Book__c/                      # Book object + fields
│   └── Library_Book_Loan__c/                 # Loan object + fields
└── permissionsets/
    └── DigiLibrary_APP.permissionset-meta.xml
```

---

## Custom Objects

### `Library_Book__c`
| Field | Type | Description |
|---|---|---|
| `Tittle__c` | Text | Book title |
| `Author__c` | Text | Author name |
| `Available_Copies__c` | Number | Copies currently available |
| `Total_Copies__c` | Number | Total copies in the library |

### `Library_Book_Loan__c`
| Field | Type | Description |
|---|---|---|
| `Book__c` | Lookup (Library_Book__c) | Book being borrowed |
| `Borrower__c` | Lookup (Contact) | Employee borrowing the book |
| `Loan_Start_Date__c` | Date | Date the loan was registered |
| `Loan_End_Date__c` | Date | Expected return date |

---

## Technical Highlights

- **Bulk-safe trigger**: single SOQL + single DML per transaction context, validated with 200-record tests
- **Double validation**: `LibraryService` throws `NoAvailableCopiesException` before DML; trigger enforces the same rule at database level
- **SOSL over SOQL**: cross-field search in a single query
- **`with sharing`** on all Apex classes for record-level security
- **Modern LWC API 66**: `lwc:if` / `lwc:else` directives, no deprecated `if:true`
- **Per-row processing state**: each loan button tracks its own in-flight request independently

---

## Deployment

```bash
# Authenticate to your org
sf org login web --alias myOrg

# Deploy all components
sf project deploy start --source-dir force-app

# Run all tests
sf apex run test --test-level RunLocalTests --wait 10
```

---

## Author

**Luis Hernandez**  
Salesforce Developer  
API Version: 66.0
