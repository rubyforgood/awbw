# Deduplication UI Documentation

## Overview

The deduplication UI provides a web-based interface for managing and merging duplicate categories and sectors in the AWBW portal. This feature helps administrators clean up duplicate records that may have been created with different casing or slight variations in naming.

## Features

### 1. Dedupe Index Page

**URL Paths:**
- Categories: `/categories/dedupe_index`
- Sectors: `/sectors/dedupe_index`

**Key Features:**
- **Navigation Tabs**: Toggle between "Possible dupes" view and main index
- **Selection Interface**: Two dropdown menus to select which records to merge:
  - "Record to delete" (left dropdown)
  - "Record to keep" (right dropdown)
- **Action Buttons**:
  - "Preview this dedupe" button (green) - Shows detailed comparison
  - "Clear" button (gray) - Resets the form
- **Duplicate Groups List**: Shows all detected duplicate groups with:
  - Normalized name used for grouping
  - Count of duplicates in each group
  - Details for each record: ID, published status, associated taggings count
  - For categories: also shows category type

**Design:**
- Purple header bar matching the theme from reference screenshots
- Clean, organized list of duplicate groups
- Color-coded status badges (green for published, gray for unpublished)

### 2. Dedupe Preview Page

**Accessed via:** Submitting the form on the dedupe index page

**Key Features:**
- **Side-by-Side Comparison**:
  - Left panel: Record to DELETE (red theme with trash icon)
  - Right panel: Record to KEEP (green theme with checkmark icon)
- **Field-by-Field Comparison** showing:
  - ID
  - Name
  - Published status
  - Category Type (categories only)
  - Position (categories only)
  - Created timestamp
  - Associated records count
- **Difference Highlighting**: Fields that differ between the two records are highlighted in yellow with "DIFFERENT" label
- **Associated Records Lists**: Scrollable lists showing all tagged items for each record
- **Warning Banner**: Yellow warning explaining the irreversible nature of the action
- **Action Buttons**:
  - "Execute Merge" button (red) - Performs the merge with confirmation dialog
  - "Cancel" button (gray) - Returns to dedupe index

**Safety Features:**
- Visual distinction between delete (red) and keep (green) records
- Prominent warning about permanent deletion
- Browser confirmation dialog before execution
- Transaction-based merging to ensure data integrity

### 3. Execution and Results

**Process:**
1. User selects records to merge and clicks "Preview this dedupe"
2. System displays side-by-side comparison
3. User reviews differences and clicks "Execute Merge"
4. Browser shows confirmation dialog
5. System performs merge using the deduper service:
   - Moves all associations from deleted record to kept record
   - Removes duplicate associations if they already exist on kept record
   - Permanently deletes the duplicate record
6. User redirected to main index with success message

**Error Handling:**
- Validation errors redirect back to dedupe index with alert message
- Transaction rollback on any failure
- Detailed error messages in flash alerts

## UI Design Principles

- **Purple Theme**: Primary action areas use purple (#7C3AED) to match the reference design
- **Color Coding**: 
  - Red for deletion actions
  - Green for kept/success states
  - Yellow for warnings and differences
  - Gray for neutral/cancel actions
- **Responsive Design**: Works on desktop and mobile using Tailwind CSS grid system
- **Accessibility**: Clear labels, proper button semantics, keyboard navigation support
- **FontAwesome Icons**: Consistent iconography throughout

## Navigation

Access the deduplication interface from:
1. Categories index page: "Dedupe" button in header
2. Sectors index page: "Dedupe" button in header
3. Direct URL navigation to `/categories/dedupe_index` or `/sectors/dedupe_index`

## Technical Implementation

**Backend:**
- Uses `CategoryDeduper` and `SectorDeduper` service classes
- Duplicate detection based on case-insensitive, normalized names
- Safe transaction-based merging
- Detailed Rails logging of all operations

**Frontend:**
- Server-rendered ERB templates
- Tailwind CSS for styling
- FontAwesome for icons
- Turbo for form submissions with confirmation dialogs

**Authorization:**
- Admin-only access via existing authorization system
- All actions require `authorize!` call
