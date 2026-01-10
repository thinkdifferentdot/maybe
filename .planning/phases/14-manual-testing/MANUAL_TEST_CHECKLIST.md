# v1.1 AI Auto-Categorization - Manual Testing Checklist

**Testing Date:** _______________

**Instructions:**
1. Open this document in your browser
2. Open the application in a separate tab/window at `http://localhost:3000`
3. Work through each feature section, checking off items as you verify them
4. Note any issues in the "Issues Found" section at the bottom

---

## Prerequisites

- [X] Development server running (`bin/dev`)
- [X] Logged in as admin user (required for Settings page)
- [X] Test data available (uncategorized transactions, or CSV file to import)
- [X] AI provider configured in Settings (OpenAI or Anthropic with valid API key)

---

## Feature 1: Settings UI (Phase 10)

**URL:** `/settings/auto_categorization`

### 1.1 Settings Page Access

- [X] Navigate to Settings → Auto Categorization
- [X] Verify page loads without errors
- [ ] Verify all three toggle switches are visible:
  - [ ] "Auto-categorize on CSV import"
  - [ ] "Auto-categorize on sync"
  - [ ] "Auto-categorize on UI action"
// Toggles are visible, but there's no labels. They are just arranged in a row.


### 1.2 Toggle Functionality

- [ ] Toggle "Auto-categorize on CSV import" to ON
- [ ] Refresh the page
- [ ] Verify toggle state persists (still ON)

- [ ] Toggle "Auto-categorize on sync" to ON
- [ ] Toggle "Auto-categorize on UI action" to ON
- [ ] Refresh the page
- [ ] Verify all three toggles persist in ON state

### 1.3 Toggle OFF States

- [ ] Toggle all three settings to OFF
- [ ] Refresh the page
- [ ] Verify all toggles persist in OFF state

### 1.4 Edge Cases

- [ ] Try accessing page as non-admin user
- [ ] Verify access is denied (redirect or error)

---

## Feature 2: CSV Import AI Trigger (Phase 11-02)

**URL:** `/imports/new`

### 2.1 Import WITH AI Categorization Enabled

**Setup:**
- [ ] Enable "Auto-categorize on CSV import" in Settings
- [ ] Prepare a CSV file with transactions that have NO category column

**Test:**
- [ ] Navigate to Transactions → Import
- [ ] Upload the CSV file
- [ ] Complete the import flow
- [ ] Navigate to Transactions page
- [ ] Verify imported transactions appear
- [ ] Wait 10-30 seconds for AI job to complete
- [ ] Refresh Transactions page
- [ ] Verify previously uncategorized transactions now have categories
- [ ] Verify confidence badges appear on AI-categorized transactions

### 2.2 Import WITHOUT AI Categorization

**Setup:**
- [ ] Disable "Auto-categorize on CSV import" in Settings
- [ ] Prepare a CSV file with transactions that have NO category column

**Test:**
- [ ] Upload the CSV file
- [ ] Complete the import flow
- [ ] Navigate to Transactions page
- [ ] Verify imported transactions appear
- [ ] Verify imported transactions remain UNCATEGORIZED
- [ ] Wait 30 seconds and refresh
- [ ] Verify transactions still have no categories (AI did not run)

### 2.3 Import WITH User-Provided Categories

**Setup:**
- [ ] Enable "Auto-categorize on CSV import" in Settings
- [ ] Prepare a CSV file WITH category column filled in

**Test:**
- [ ] Upload the CSV file
- [ ] Complete the import flow
- [ ] Verify imported transactions have the USER-PROVIDED categories
- [ ] Verify AI did NOT override user categories

---

## Feature 3: Individual AI Categorize Button (Phase 12-02)

**URL:** `/transactions`

### 3.1 Button Visibility

- [X] Navigate to Transactions page
- [X] Verify each transaction row has an "AI" button (sparkle icon) in the Category column

### 3.2 Categorize Uncategorized Transaction

**Test:**
- [ ] Find an uncategorized transaction
- [ ] Click the "AI" button next to it
- [ ] Verify button shows loading state (spinner icon)
- [ ] Wait for categorization to complete (few seconds)
- [ ] Verify category appears inline
- [ ] Verify confidence badge appears next to category

### 3.3 Confidence Badge Display

**Expected colors:**
- Green badge: confidence > 80%
- Yellow badge: confidence 60-80%
- Orange badge: confidence < 60%

- [ ] Find or create an AI-categorized transaction with high confidence (>80%)
- [ ] Verify confidence badge is GREEN

- [ ] Find or create an AI-categorized transaction with medium confidence (60-80%)
- [ ] Verify confidence badge is YELLOW

- [ ] Find or create an AI-categorized transaction with low confidence (<60%)
- [ ] Verify confidence badge is ORANGE

### 3.4 Re-categorize Existing Transaction

- [ ] Find a transaction that already has a category
- [ ] Click the "AI" button
- [ ] Verify AI can re-categorize (category updates)
- [ ] Verify new confidence badge appears

### 3.5 Error Handling

- [ ] Try clicking AI button with INVALID API key configured
- [ ] Verify error message appears (flash notification)
- [ ] Verify transaction remains unchanged

### 3.6 Setting Integration

**Setup:**
- [ ] Disable "Auto-categorize on UI action" in Settings (if available)

**Test:**
- [ ] Try clicking AI button
- [ ] Verify button is disabled or shows "not enabled" message

---

## Feature 4: Bulk AI Categorization (Phase 12-03)

**URL:** `/transactions`

### 4.1 Bulk Button Visibility

- [ ] Navigate to Transactions page
- [ ] Select at least one transaction (click checkbox)
- [ ] Verify selection bar appears at bottom
- [ ] Verify "AI Categorize" button appears in selection bar
- [ ] Verify cost estimate is displayed (e.g., "Est: $0.02")

### 4.2 Cost Estimation

- [ ] Select 1 transaction
- [ ] Note the cost estimate displayed

- [ ] Select 5 transactions
- [ ] Verify cost estimate increases proportionally

- [ ] Select 10 transactions
- [ ] Verify cost estimate is higher than for 5 transactions

### 4.3 Bulk Categorize - All High Confidence

**Setup:**
- [ ] Select 2-3 uncategorized transactions

**Test:**
- [ ] Click "AI Categorize" button
- [ ] Verify confirmation dialog appears (if any low-confidence)
- [ ] Confirm the action
- [ ] Verify all selected transactions are categorized
- [ ] Verify confidence badges appear
- [ ] Verify summary modal shows results
- [ ] Verify summary modal auto-dismisses after 5 seconds

### 4.4 Bulk Categorize - Mixed Confidence

**Setup:**
- [ ] Select multiple transactions (5+ if possible)
- [ ] Note: Some may return low confidence scores

**Test:**
- [ ] Click "AI Categorize" button
- [ ] If low confidence confirmation appears, verify it lists suggestions
- [ ] Confirm or approve suggestions
- [ ] Verify all transactions are categorized

### 4.5 Partial Error Handling

**Setup:**
- [ ] Select transactions where some might fail (e.g., edge cases)

**Test:**
- [ ] Click "AI Categorize" button
- [ ] Verify successful transactions are categorized
- [ ] Verify failed transactions show error state
- [ ] Verify batch process continues despite individual errors

### 4.6 Selection Handling

- [ ] Select only CATEGORIZED transactions
- [ ] Click "AI Categorize" button
- [ ] Verify behavior (should still work, allows re-categorization)

- [ ] Mix of categorized and uncategorized transactions
- [ ] Click "AI Categorize" button
- [ ] Verify all selected transactions are processed

---

## Confidence Badge Testing (All Views)

### Desktop View
- [ ] View transactions on desktop screen
- [ ] Verify confidence badges appear next to category names
- [ ] Verify color coding is correct (green/yellow/orange)

### Mobile View
- [ ] Resize browser to mobile width
- [ ] Verify confidence badges appear on mobile transaction rows
- [ ] Verify color coding matches desktop view

---

## Issues Found

Use this section to document any issues discovered during testing:

| Issue | Feature | Severity | Notes |
|-------|---------|----------|-------|
|       |         |          |       |
|       |         |          |       |
|       |         |          |       |
|       |         |          |       |

---

## Overall Sign-off

- [ ] All critical features tested
- [ ] All edge cases tested
- [ ] No blocking issues found
- [ ] Ready for milestone v1.1 completion

**Tester:** _______________
**Date:** _______________
