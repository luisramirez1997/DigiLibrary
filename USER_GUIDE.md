# DigiLibrary — User Guide

**Version:** 1.0  
**Author:** Luis Hernandez  
**Last Updated:** 2026-03-31

---

## Table of Contents

1. [What is DigiLibrary?](#1-what-is-digilibrary)
2. [Before You Start — Access Setup](#2-before-you-start--access-setup)
3. [How to Open the App](#3-how-to-open-the-app)
4. [How to Search for a Book](#4-how-to-search-for-a-book)
5. [How to Request a Book Loan](#5-how-to-request-a-book-loan)
6. [Understanding the Results Table](#6-understanding-the-results-table)
7. [How to Return a Book](#7-how-to-return-a-book)
8. [Managing Books (Admin)](#8-managing-books-admin)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. What is DigiLibrary?

DigiLibrary is a corporate book library system built inside Salesforce. It lets you:

- Search for books available in the library by title or author
- See how many copies are available in real time
- Request a loan and assign it to any employee (Contact)
- Track all active loans from the Library Book Loans tab

---

## 2. Before You Start — Access Setup

### Who needs to do this?

A **Salesforce Administrator** must complete this setup once per user before they can use the app.

---

### Step 1 — Assign the Permission Set

The `DigiLibrary APP` permission set grants all required access. Without it, users will not see the app or its data.

**How to assign it:**

1. Go to **Setup** (gear icon, top right)
2. Search for **Users** in the Quick Find box → click **Users**
3. Click on the user's name
4. Scroll down to the **Permission Set Assignments** section
5. Click **Edit Assignments**
6. Find **DigiLibrary APP** in the Available list → click **Add**
7. Click **Save**

The user now has access. No logout/login required.

---

### What does the permission set grant?

| What | Why it's needed |
|---|---|
| Access to the **DigiLibrary** app | So the app appears in the App Launcher |
| Read + Write on **Library Book** records | To search and view books |
| Read + Write on **Library Book Loan** records | To create and view loans |
| Read on **Contact** records | So the borrower picker can find employees |
| Access to all book and loan fields | To display title, author, copies, dates |
| Access to Apex classes (LibraryService, etc.) | So the search and loan buttons work |
| Visibility of Library Books and Loans tabs | So the tabs appear in the navigation bar |

> If a user reports that a button doesn't work or data doesn't load, the first thing to check is whether the permission set has been assigned.

---

### Step 2 — Make sure Contacts exist

The borrower picker in the app searches for **Contact** records. Each employee who will borrow books should have a Contact record in Salesforce.

To create a Contact:
1. Go to the **Contacts** tab (or any app that includes it)
2. Click **New**
3. Fill in at least the **Last Name**
4. Save

---

### Step 3 — Make sure Books exist

Before users can search, a library administrator needs to create `Library Book` records.

To create a book:
1. Open the **DigiLibrary** app
2. Click the **Library Books** tab
3. Click **New**
4. Fill in:
   - **Library Book Name** — internal record name
   - **Title** (`Tittle__c`) — the book's title
   - **Author** — the author's name
   - **Total Copies** — how many physical copies exist
   - **Available Copies** — how many are currently available (usually same as Total on creation)
5. Click **Save**

---

## 3. How to Open the App

1. Click the **App Launcher** (9-dot grid icon, top left)
2. Search for **DigiLibrary**
3. Click the app to open it

You will land on the DigiLibrary home page with the **Book Search** component.

---

## 4. How to Search for a Book

1. In the **"Search by title or author"** field, type a keyword
   - You can search by part of the title: `"Prince"` will find `"El Principito"`
   - You can search by author: `"Martin"` will find books by Robert Martin
2. Press **Enter** or click the **Search** button
3. Results appear in the table below

**Tips:**
- The search is not case-sensitive
- At least 2 characters are recommended for meaningful results
- Leaving the field blank and clicking Search does nothing — a term is required

---

## 5. How to Request a Book Loan

Once you have search results:

1. In the **"Borrower (Contact)"** picker, start typing the employee's name
2. Select the correct Contact from the dropdown
3. In the results table, find the book you want
4. Click **Request Loan** on that book's row

**What happens next:**
- The button shows **"Processing..."** while the request is being registered
- A **green success toast** appears at the top: _"Loan registered successfully!"_
- The search resets automatically so you can start a new search
- The loan is now visible under the **Library Book Loans** tab

---

### Important rules

| Rule | Explanation |
|---|---|
| You must select a borrower before clicking Request Loan | If no borrower is selected, a warning toast will appear: _"Please select a borrower contact first."_ |
| Books with 0 available copies cannot be loaned | The Action column shows **"⚠ No copies available"** instead of a button |
| One loan request at a time per row | The button is disabled while a request is in progress |

---

## 6. Understanding the Results Table

| Column | Description |
|---|---|
| **Title** | The book's title |
| **Author** | The book's author |
| **Available** | Copies available right now — shown as a colored badge |
| **Total** | Total copies owned by the library |
| **Action** | Loan button or unavailability message |

### Availability Badge Colors

| Badge | Meaning |
|---|---|
| Green badge | Copies are available — you can request a loan |
| Red badge | No copies available — all are currently on loan |

---

## 7. How to Return a Book

Book returns are currently handled by **deleting the loan record**. When a loan record is deleted, the system automatically increments the book's available copies back.

**To return a book:**

1. Go to the **Library Book Loans** tab
2. Find the loan record for the book being returned
3. Click on the loan record to open it
4. Click **Delete**
5. Confirm the deletion

The book's **Available Copies** counter will increase by 1 automatically.

> **Note for admins:** A future improvement would be adding a "Status" field (Active/Returned) so returns can be tracked without deleting records and full loan history is preserved.

---

## 8. Managing Books (Admin)

### Editing a Book Record

1. Go to the **Library Books** tab
2. Click on a book record
3. Click **Edit**
4. Update the fields as needed
5. Save

> **Warning:** Do not manually edit `Available_Copies__c` while loans are active — this field is managed automatically by the system. Manual edits can cause it to go out of sync with actual loans.

### Viewing All Loans for a Book

1. Open a **Library Book** record
2. Look for the **Library Book Loans** related list (if configured on the page layout)
3. All active loans for that book will be listed there

### Viewing All Loans

Go to the **Library Book Loans** tab to see all loan records across all books.

---

## 9. Troubleshooting

| Problem | Likely Cause | Solution |
|---|---|---|
| App doesn't appear in App Launcher | Permission set not assigned | Admin assigns `DigiLibrary APP` permission set |
| Search returns no results | No books created, or search term too vague | Create Library Book records; try a shorter keyword |
| "Request Loan" button is missing | Book has 0 available copies | Wait for a copy to be returned, or add more total copies |
| "Please select a borrower" warning | No Contact selected in the picker | Select a Contact from the Borrower picker first |
| Borrower picker shows no results | Contact doesn't exist, or no Contact read permission | Create a Contact for the employee; check permission set |
| Loan request shows an error toast | System-level error (duplicate, validation rule, etc.) | Note the error message and contact your Salesforce admin |
| Available copies seem wrong | Manual edit or data issue | Admin should audit loan records vs. Available_Copies__c manually |
| Tabs not visible in the app | Permission set not assigned or tab not added to the app | Assign permission set; check App Builder for tab configuration |

---

## Quick Reference Card

```
TO SEARCH A BOOK:
  1. Open DigiLibrary app
  2. Type title or author → press Enter or Search

TO REQUEST A LOAN:
  1. Search for the book
  2. Select a Borrower (Contact)
  3. Click "Request Loan"

TO RETURN A BOOK:
  1. Go to Library Book Loans tab
  2. Find the loan → Delete it

TO ADD A BOOK (Admin):
  1. Go to Library Books tab → New
  2. Fill Title, Author, Total Copies, Available Copies → Save

TO GRANT ACCESS (Admin):
  1. Setup → Users → [User] → Permission Set Assignments
  2. Add "DigiLibrary APP" → Save
```
