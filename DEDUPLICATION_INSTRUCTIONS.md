# Tag and Tagging Deduplication Instructions

## Overview

This document provides step-by-step instructions for deduplicating sectors, categories, and their associated taggings (sectorable_items and categorizable_items) in the production database.

**Important**: The migration file `20260119163954_add_unique_indexes_to_taggings.rb` adds unique indexes that will fail if duplicate data exists. Therefore, you must run the deduplication rake tasks **before** running the migration.

## Prerequisites

- Database backup completed
- Access to production console/server
- Rails environment configured

## Step-by-Step Execution Order

### Step 1: Review Current Duplicates (Dry Run)

First, analyze what duplicates exist without making any changes:

```bash
# Check for duplicate sector assignments
bundle exec rake tags:dedupe_assignments DRY_RUN=true

# Check for duplicate sectors
bundle exec rake tags:dedupe_sectors DRY_RUN=true

# Check for duplicate categories
bundle exec rake tags:dedupe_categories DRY_RUN=true
```

Review the output carefully to understand what will be merged/deleted.

### Step 2: Clean Up Duplicate Assignments

Remove duplicate tagging entries (same tag assigned multiple times to the same item):

```bash
bundle exec rake tags:dedupe_assignments DRY_RUN=false
```

This task:
- Finds duplicate sectorable_items (same sector_id + sectorable_type + sectorable_id)
- Finds duplicate categorizable_items (same category_id + categorizable_type + categorizable_id)
- Keeps the first record (lowest ID) and deletes the rest

### Step 3: Deduplicate Sectors

Merge duplicate sectors (same name with different cases/spacing):

```bash
bundle exec rake tags:dedupe_sectors DRY_RUN=false
```

This task:
- Groups sectors by normalized name (lowercase, stripped)
- Keeps the "best" sector (published > highest usage > oldest)
- Reassigns all sectorable_items to the primary sector
- Deletes duplicate tagging entries if the primary already has that assignment
- Deletes the duplicate sectors

Optional parameters:
- `MIN_USAGE=N` - Only dedupe groups with at least N total usages (default: 0)

Example with minimum usage threshold:
```bash
bundle exec rake tags:dedupe_sectors DRY_RUN=false MIN_USAGE=5
```

### Step 4: Deduplicate Categories

Merge duplicate categories (same name with different cases/spacing):

```bash
bundle exec rake tags:dedupe_categories DRY_RUN=false
```

This task:
- Groups categories by normalized name (lowercase, stripped)
- Keeps the "best" category (published > highest usage > oldest)
- Reassigns all categorizable_items to the primary category
- Deletes duplicate tagging entries if the primary already has that assignment
- Deletes the duplicate categories

Optional parameters:
- `MIN_USAGE=N` - Only dedupe groups with at least N total usages (default: 0)

### Step 5: Run the Migration

After all duplicates are removed, run the migration to add unique indexes:

```bash
bundle exec rails db:migrate
```

This will add:
- Unique index on `sectorable_items` (sector_id, sectorable_type, sectorable_id)
- Unique index on `categorizable_items` (category_id, categorizable_type, categorizable_id)

These indexes, combined with the model validations, will prevent future duplicates.

## Verification

After completing all steps, verify the results:

```bash
# Check for any remaining duplicate sectorable_items
bundle exec rails runner "puts SectorableItem.group(:sector_id, :sectorable_type, :sectorable_id).having('COUNT(*) > 1').count"

# Check for any remaining duplicate categorizable_items
bundle exec rails runner "puts CategorizableItem.group(:category_id, :categorizable_type, :categorizable_id).having('COUNT(*) > 1').count"

# Check for any remaining duplicate sectors
bundle exec rails runner "puts Sector.group('LOWER(TRIM(name))').having('COUNT(*) > 1').count"

# Check for any remaining duplicate categories
bundle exec rails runner "puts Category.group('LOWER(TRIM(name))').having('COUNT(*) > 1').count"
```

All counts should return 0.

## Rollback Strategy

If issues arise:

1. **Before migration**: Simply restore from backup. The rake tasks make changes but don't alter schema.

2. **After migration**: 
   ```bash
   # Rollback the migration
   bundle exec rails db:rollback
   
   # Restore database from backup if needed
   ```

## Important Safety Features

The rake tasks include several safety mechanisms:

- **DRY_RUN mode**: Defaults to `true`, must explicitly set to `false` to make changes
- **Transaction wrapping**: All changes wrapped in database transactions
- **Duplicate detection**: Checks for existing taggings before reassigning
- **Validation**: Ensures no orphaned records remain before deleting
- **Detailed logging**: All operations logged to stdout

## Common Issues

### Migration fails with "duplicate entry" error

**Cause**: Duplicates still exist in the database.

**Solution**: Re-run the appropriate deduplication rake task, then retry the migration.

### "ABORT: X items still reference sector/category Y"

**Cause**: Unexpected issue during tagging reassignment.

**Solution**: Transaction was rolled back automatically. Review logs and contact development team.

## Code Storage

To store these changes in your repository without triggering migration failures:

1. **Commit the code** (already done in this PR):
   - Migration file: `db/migrate/20260119163954_add_unique_indexes_to_taggings.rb`
   - Rake tasks: `lib/tasks/tag_deduping.rb`
   - Model validations: Already present in `app/models/sectorable_item.rb` and `app/models/categorizable_item.rb`

2. **Deploy strategy**:
   - Deploy the code (migration will NOT run automatically with most deployment strategies)
   - SSH into production server
   - Follow steps 1-5 above
   - Restart application if needed

3. **For existing environments** (development, staging):
   - Pull the latest code
   - Run deduplication tasks if database has duplicates
   - Run migration

4. **For new environments** (fresh database):
   - Just run `bundle exec rails db:migrate`
   - No deduplication needed since database is empty

## Summary

**Correct execution order**:
1. `tags:dedupe_assignments DRY_RUN=false` - Remove duplicate tagging entries
2. `tags:dedupe_sectors DRY_RUN=false` - Merge duplicate sectors
3. `tags:dedupe_categories DRY_RUN=false` - Merge duplicate categories
4. `rails db:migrate` - Add unique indexes

**DO NOT** run `rails db:migrate` before running the rake tasks, or the migration will fail on databases with existing duplicates.
