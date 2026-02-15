# Migration Notes for Issue #849

## Overview
This PR converts the `quotable_item_quotes` join table pattern to a direct polymorphic relationship between `quotes` and quotable items (workshops, reports, workshop_logs).

## Database Migrations

Two migrations have been added:

### 1. Add Quotable Columns to Quotes (20260215071524)
```ruby
add_reference :quotes, :quotable, polymorphic: true, index: true
```
This adds `quotable_id` and `quotable_type` columns to the `quotes` table.

### 2. Migrate Data (20260215071525)
```sql
UPDATE quotes
INNER JOIN quotable_item_quotes ON quotes.id = quotable_item_quotes.quote_id
SET quotes.quotable_id = quotable_item_quotes.quotable_id,
    quotes.quotable_type = quotable_item_quotes.quotable_type
```
This copies the associations from the join table to the quotes table.

## Running Migrations

```bash
# Development
bundle exec rails db:migrate

# Docker
docker compose exec web bundle exec rails db:migrate

# Or using mise
mise docker-exec rails db:migrate
```

## Rollback Plan

The data migration is reversible:
```bash
bundle exec rails db:rollback STEP=2
```

This will:
1. Clear the `quotable_id` and `quotable_type` columns on quotes
2. Remove the columns from the quotes table

The original `quotable_item_quotes` table data is preserved and can be used to restore the relationship.

## Testing the Changes

```bash
# Run model tests
bundle exec rspec spec/models/quote_spec.rb
bundle exec rspec spec/models/workshop_spec.rb
bundle exec rspec spec/models/report_spec.rb

# Run all tests
bundle exec rspec
```

## Future Work

After verifying this works in production:
- [ ] Remove the `quotable_item_quotes` table with a new migration
- [ ] Archive or remove the `QuotableItemQuote` model
- [ ] Remove the `quotable_item_quotes` factory

## Changes Made

### Models
- **Quote**: Added `belongs_to :quotable, polymorphic: true, optional: true`
- **Workshop**: Changed from `has_many :quotable_item_quotes` to `has_many :quotes, as: :quotable`
- **Report**: Changed from `has_many :quotable_item_quotes` to `has_many :quotes, as: :quotable`
- **Report**: Updated nested attributes from `quotable_item_quotes` to `quotes`

### Controllers
- **WorkshopLogsController**: Simplified form building logic to use direct quote associations
- **WorkshopLogsController**: Updated permitted params to use `quotes_attributes`

### Views
- **workshop_logs/_form.html.erb**: Updated to use `:quotes` instead of `:quotable_item_quotes`
- **workshop_logs/_quote_fields.html.erb**: New simplified partial for quote fields
- **quotes/index.html.erb**: Updated to use direct `quote.quotable` instead of iterating through `quotable_item_quotes`
- **quotes/show.html.erb**: Updated to use direct `@quote.quotable` instead of iterating through `quotable_item_quotes`

### Decorators
- **QuoteDecorator**: Simplified to use `object.quotable` instead of `object.quotable_item_quotes.last&.quotable`

### Tests
- **spec/models/quote_spec.rb**: Added tests for polymorphic association
- **spec/models/workshop_spec.rb**: Updated association tests
- **spec/models/report_spec.rb**: Updated association tests
