# The single row of app-wide settings an admin edits on /admin/settings: which
# Organization this portal runs as, the mailboxes it writes from, and the invoice
# and membership defaults.
#
# Every reader falls back to ENV and then to a built-in default, so a blank field
# means "use the deployment's value" rather than "no value", and a deployment with
# no row at all keeps working exactly as before.
class Setting < ApplicationRecord
  DEFAULT_ORGANIZATION_NAME = "A Window Between Worlds".freeze
  DEFAULT_INVOICE_PREFIX = "INV".freeze
  DEFAULT_ANNUAL_MEMBERSHIP_CENTS = 2500
  DEFAULT_MEMBERSHIP_RENEWAL_WINDOW_DAYS = 30
  DEFAULT_MEMBERSHIP_GRACE_PERIOD_DAYS = 30

  belongs_to :organization, optional: true

  # singleton is a constant true behind a unique index: MySQL has no CHECK-based
  # way to cap a table at one row, but a unique index on a constant does it.
  validates :singleton, uniqueness: true
  validates :info_email, :reply_to_email, :programs_email, :no_reply_email,
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" },
            allow_blank: true
  validates :invoice_prefix, length: { maximum: 20 }
  validates :annual_membership_cents, :membership_renewal_window_days, :membership_grace_period_days,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  after_commit { Current.setting = nil }

  # The row's value for a field, or nil when the database or column isn't there yet,
  # so a rake task can boot the app to create or migrate the very schema it reads.
  def self.stored(field)
    return nil unless schema_ready?(field)

    current.public_send(field).presence
  end
  private_class_method :stored

  def self.schema_ready?(field)
    table_exists? && column_names.include?(field.to_s)
  rescue ActiveRecord::NoDatabaseError
    false
  end
  private_class_method :schema_ready?

  # Memoized for the request: the mailbox is read by a footer on every page.
  # Unsaved when no row exists yet, so every reader still answers.
  def self.current
    Current.setting ||= first || new
  end

  # The organization this portal runs as. Supplies the invoice and receipt header,
  # and marks the grants it funds as subsidy rather than external funding. The name
  # match is the fallback for deployments where nobody has picked one yet.
  def self.app_organization
    return nil unless schema_ready?(:organization_id)

    current.app_organization
  end

  # Memoized on the row, which is itself memoized for the request, so the repeat
  # callers (Grant.self_funded_ids, InvoiceIssuer, the footer) cost one lookup.
  def app_organization
    @app_organization ||= organization || Organization.find_by(name: self.class.organization_name)
  end

  def self.organization_name
    ENV.fetch("ORGANIZATION_NAME", DEFAULT_ORGANIZATION_NAME)
  end

  # The return address on invoices and receipts, one line per line of the field.
  def self.organization_address_lines
    address_lines(stored(:organization_address))
  end

  # Where cheques are mailed, which is a different address from the return address.
  def self.remittance_address_lines
    address_lines(stored(:remittance_address))
  end

  def self.address_lines(value)
    value.to_s.lines.map(&:strip).reject(&:blank?)
  end
  private_class_method :address_lines

  # The public contact mailbox, shown on the contact page, the story-share footer,
  # and the invoice/receipt header.
  def self.info_email
    stored(:info_email) || ENV["INFO_EMAIL"].presence || programs_email
  end

  # The staffed programs mailbox: the reply_to on portal mail and the address users
  # are told to write to.
  def self.programs_email
    stored(:programs_email) || ENV["PROGRAMS_EMAIL"].presence || reply_to_email
  end

  # The unattended sending mailbox, used as the from: on event mail so replies land
  # in the programs mailbox instead.
  def self.no_reply_email
    stored(:no_reply_email) || ENV["NO_REPLY_EMAIL"].presence || reply_to_email
  end

  def self.reply_to_email
    stored(:reply_to_email) || ENV["REPLY_TO_EMAIL"].presence
  end

  # Leading tag on generated invoice numbers, e.g. "INV-004".
  def self.invoice_prefix
    stored(:invoice_prefix) || ENV["INVOICE_PREFIX"].presence || DEFAULT_INVOICE_PREFIX
  end

  def self.annual_membership_cents
    stored(:annual_membership_cents) ||
      ENV.fetch("ANNUAL_MEMBERSHIP_CENTS", DEFAULT_ANNUAL_MEMBERSHIP_CENTS).to_i
  end

  # How many days before a membership term ends its renewal invoice is generated.
  def self.membership_renewal_window_days
    stored(:membership_renewal_window_days) ||
      ENV.fetch("ANNUAL_MEMBERSHIP_RENEWAL_WINDOW_DAYS", DEFAULT_MEMBERSHIP_RENEWAL_WINDOW_DAYS).to_i
  end

  # How long past a term's start an unpaid membership invoice still reads as current.
  def self.membership_grace_period_days
    stored(:membership_grace_period_days) ||
      ENV.fetch("ANNUAL_MEMBERSHIP_GRACE_PERIOD_DAYS", DEFAULT_MEMBERSHIP_GRACE_PERIOD_DAYS).to_i
  end
end
