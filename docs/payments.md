# Payments

## Stack

**pay gem** + **stripe gem** (https://github.com/pay-rails/pay)

- `Person` model: `pay_customer default_payment_processor: :stripe`
- Stripe config via `.env` env vars (not Rails credentials)
- No custom webhook controller — pay gem auto-mounts `POST /pay/webhooks/stripe`

## Data Model

### Payment (STI parent)

Fields: `amount_cents`, `amount_cents_remaining`, `currency`, `payer_type`, `person_id`/`organization_id`, `pay_charge_id`, `type`, `metadata` (JSON), `check_number`, `memo`.

Subclasses:

- **CashPayment** — manual cash, created by admins
- **CheckPayment** — manual check, requires `check_number`
- **ExternalProcessorPayment** — auto-created from Stripe charges (linked to `Pay::Charge`)

> **Why duplicate Stripe data?** `ExternalProcessorPayment` intentionally mirrors what's in the pay gem's `pay_charges` table. We own the `Payment` model and its STI hierarchy, so we keep our own records rather than coupling business logic to the pay gem's schema.

### Allocation

Polymorphic join: `source` (Payment / Scholarship / Refund / Discount) → `allocatable` (EventRegistration).

- `amount` in cents
- Tracks how much of a payment has been applied to each registration
- Supports overpayment (one payment → multiple registrations) and partial payments (multiple payments → one registration)
- Reverted allocations use `reverted_id` (points back to the original allocation)

### Refund

- `method`: stripe | check | cash
- Stripe refunds: auto-synced from the charge via `PayChargeExtensions`
- Creates an allocation with negative amount to free up `amount_cents_remaining` on the payment

### Discount

- Simple `amount_cents`, creates allocations like a payment
- No payer — admin-applied credit

### Scholarship

- Belongs to a `Person` (recipient), optionally linked to a `Grant`
- On task completion, auto-creates / updates its `Allocation` to the event registration

## Payment Flows

### 1. Authenticated Event Registration

`Events::RegistrationsController#create` → if cost > 0 and not paid in full:

1. `person.set_payment_processor :stripe`
2. Stripe Checkout Session created with `metadata: { event_registration_id: registration.id }`
3. User completes payment on Stripe
4. Stripe sends webhook → pay gem creates `Pay::Charge`
5. `PayChargeExtensions#create_external_processor_payment` fires (`after_save_commit`):
   - Reads `metadata["event_registration_id"]`
   - Creates `ExternalProcessorPayment` + `Allocation` for remaining cost

### 2. Public Registration

`Events::PublicRegistrationsController#create` → same Stripe Checkout flow when payment method is "Credit Card Now".

### 3. Bulk Payment

`Events::BulkPaymentsController#create` → creates `FormSubmission` (role: "bulk_payment") → Stripe Checkout with `metadata: { form_submission_id: submission.id }` → webhook creates `ExternalProcessorPayment` (no auto-allocation; admin manually allocates).

### 4. Admin Cash / Check

`PaymentsController#create` — directly creates `CashPayment` or `CheckPayment`, no Stripe involved. Admin allocates manually.

## PayChargeExtensions (the glue)

Concern mixed into `Pay::Charge` in `config/initializers/pay.rb`.

- `after_save_commit :create_external_processor_payment` — dispatches on `metadata` keys
- `after_save_commit :sync_refunds` — creates local `Refund` records from Stripe refund data
- Checks `ExternalProcessorPayment.exists?(pay_charge_id:)` to avoid duplicates (idempotent)

## Environment Variables (`.env`)

```
STRIPE_PUBLIC_KEY=pk_test_...       # Publishable key
STRIPE_PRIVATE_KEY=sk_test_...      # Secret key
STRIPE_WEBHOOK_RECEIVE_TEST_EVENTS=true  # Allow test-mode events without webhook cycle
STRIPE_SIGNING_SECRET=whsec_...     # From stripe listen CLI
```

## Local Dev with Stripe CLI

### 1. Install Stripe CLI

https://docs.stripe.com/stripe-cli

### 2. Forward webhooks

```bash
stripe listen --forward-to localhost:3000/pay/webhooks/stripe
```

The webhook endpoint `POST /pay/webhooks/stripe` is auto-mounted by `Pay::Engine` (Rails engine mounted at `/pay`). No route configuration needed.

### 3. Set signing secret

Copy the `whsec_...` secret from the `stripe listen` output into `STRIPE_SIGNING_SECRET` in `.env`.

### 4. Test a payment

```bash
stripe trigger payment_intent.succeeded
```

This simulates a complete payment. The charge won't have meaningful metadata (`event_registration_id`, etc.), so `PayChargeExtensions` won't create a local payment — but it confirms the webhook pipeline works.

To test end-to-end, go through registration in the browser. Stripe test mode accepts `4242 4242 4242 4242` (and other test card numbers) without real money.

## Stripe Dashboard Webhook URL

For production, configure in Stripe Dashboard → Developers → Webhooks:

```
https://YOUR_DOMAIN/pay/webhooks/stripe
```

## Relevant Webhook Events

- `payment_intent.succeeded` / `charge.succeeded` → triggers `PayChargeExtensions`
- `charge.refunded` → triggers refund sync

All handled by pay gem — no custom webhook controller.
