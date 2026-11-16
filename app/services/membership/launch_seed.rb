# Creates the initial membership for every active facilitator with portal access.
#
# Two passes, judged on the day the task runs
#
#   * $0 pass — people actively facilitating at one of the supplied zero-cost orgs.
#     Their membership is locked at $0, so it renews free until an admin changes it.
#   * standard pass — everyone else; the term starts at the app-wide annual price.
#
# The zero-cost org list is an input (ORG_IDS) rather than something derived here,
# because "large enough to be free" fluctuates and is owned outside the importer.
#
# Both passes skip anyone who already has an unlocked membership. Members in the $0
# set whose existing membership isn't already $0 are reported for a manual fee
# review; this task never reprices an existing membership.
class Membership::LaunchSeed
  START_DATE = Date.new(2027, 3, 1)
  TERM_END = START_DATE + Membership::INVOICE_PERIOD - 1.day

  OrgSummary = Data.define(:organization, :active_facilitators, :with_access)
  Created = Data.define(:person, :membership)
  Skipped = Data.define(:person, :memberships)
  Failure = Data.define(:person, :errors)
  MultiOrg = Data.define(:person, :organization_ids)

  Result = Data.define(
    :org_summaries,
    :eligible_zero, :eligible_standard,
    :created, :skipped_existing, :skipped_no_access, :review_fees,
    :multi_org, :failures
  ) do
    def created_zero = created.count { |row| row.membership.cost_cents == 0 }
    def created_standard = created.count { |row| row.membership.cost_cents.nil? }
    def created_count = created.size
    def no_access_count = skipped_no_access.values.sum
  end

  def self.call(org_ids:, dry_run: true, io: $stdout, actor: nil)
    new(org_ids:, dry_run:, io:, actor:).call
  end

  def initialize(org_ids:, dry_run: true, io: $stdout, actor: nil)
    @org_ids = Array(org_ids).flatten.map(&:to_i).reject(&:zero?).uniq
    @dry_run = dry_run
    @io = io
    @actor = actor
  end

  def call
    raise ArgumentError, "ORG_IDS is required" if @org_ids.empty?

    @organizations = Organization.where(id: @org_ids).order(:name).to_a
    missing = @org_ids - @organizations.map(&:id)
    raise ArgumentError, "Unknown organization IDs: #{missing.join(', ')}" if missing.any?

    Time.use_zone(Membership::TIME_ZONE) { run }
  end

  private

  def run
    @run_date = Date.current
    @io.puts "Eligibility snapshot: #{@run_date.iso8601} (active facilitators on the run day)"
    @io.puts "Membership term: #{START_DATE.iso8601} – #{TERM_END.iso8601}"
    @io.puts

    active = Affiliation.facilitators.active
    facilitators = Person.where(id: active.select(:person_id)).includes(:user, :memberships)

    zero_scope = facilitators.where(id: active.where(organization_id: @org_ids).select(:person_id))
    standard_scope = facilitators.where.not(id: zero_scope.select(:id))

    @zero_people = zero_scope.to_a
    @standard_people = standard_scope.to_a

    @org_summaries = build_org_summaries(active)
    print_org_summaries

    @created = []
    @skipped_existing = []
    @skipped_no_access = Hash.new(0)
    @review_fees = []
    @failures = []

    with_current_user do
      within_dry_run do
        process(@zero_people, cost_cents: 0, zero_cost: true)
        process(@standard_people, cost_cents: nil, zero_cost: false)
      end
    end

    result = Result.new(
      org_summaries: @org_summaries,
      eligible_zero: @zero_people.size,
      eligible_standard: @standard_people.size,
      created: @created,
      skipped_existing: @skipped_existing,
      skipped_no_access: @skipped_no_access,
      review_fees: @review_fees,
      multi_org: multi_org_rows(active),
      failures: @failures
    )
    print_summary(result)
    result
  end

  def process(people, cost_cents:, zero_cost:)
    people.each do |person|
      unlocked = person.memberships.reject(&:locked?)
      if unlocked.any?
        @skipped_existing << Skipped.new(person:, memberships: unlocked)
        @review_fees << Skipped.new(person:, memberships: unlocked) if zero_cost && unlocked.any? { |membership| membership.cost_cents != 0 }
        next
      end

      reason = missing_account_reason(person)
      if reason
        @skipped_no_access[reason] += 1
        next
      end

      create_membership(person, cost_cents:)
    rescue StandardError => e
      @failures << Failure.new(person:, errors: [ e.message ])
      @io.puts "  ! #{person.id} #{person.email}: #{e.message}"
    end
  end

  def create_membership(person, cost_cents:)
    result = Membership::Create.call(person:, start_date: START_DATE, cost_cents:)

    if result.success?
      @created << Created.new(person:, membership: result.membership)
      @io.puts "  + #{person.id} #{person.email}: #{cost_label(result.membership)}"
    else
      @failures << Failure.new(person:, errors: result.errors)
      @io.puts "  ! #{person.id} #{person.email}: #{result.errors.to_sentence}"
    end
  end

  def build_org_summaries(active)
    access_ids = User.has_access.where.not(person_id: nil).select(:person_id)

    @organizations.map do |organization|
      scope = active.where(organization_id: organization.id)
      OrgSummary.new(
        organization:,
        active_facilitators: scope.distinct.count(:person_id),
        with_access: scope.where(person_id: access_ids).distinct.count(:person_id)
      )
    end
  end

  def multi_org_rows(active)
    return [] if @zero_people.empty?

    orgs_by_person = active.where(person_id: @zero_people.map(&:id))
      .pluck(:person_id, :organization_id)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }

    @zero_people.filter_map do |person|
      organization_ids = orgs_by_person[person.id] || []
      MultiOrg.new(person:, organization_ids:) if (organization_ids - @org_ids).any?
    end
  end

  # Mirrors User#has_access? for the person's login so a skipped row can say why.
  def missing_account_reason(person)
    user = person.user
    return "no user account" if user.nil?
    return "inactive" if user.inactive?
    return "locked" if user.locked_at.present?
    return "unconfirmed" if user.confirmed_at.nil?

    nil
  end

  def cost_label(membership)
    return "standard (#{MoneyFormatter.dollars_from_cents(Membership.annual_cost_cents)})" if membership.cost_cents.nil?

    MoneyFormatter.dollars_from_cents(membership.cost_cents)
  end

  def with_current_user(&block)
    return block.call if @actor.blank?

    Current.set(user: @actor, &block)
  end

  def within_dry_run(&block)
    return block.call unless @dry_run

    ActiveRecord::Base.transaction do
      block.call
      raise ActiveRecord::Rollback
    end
  end

  def print_org_summaries
    @io.puts "Zero-cost orgs:"
    @org_summaries.each do |summary|
      @io.puts "  ##{summary.organization.id} #{summary.organization.name}: " \
               "#{summary.active_facilitators} active facilitators, #{summary.with_access} with portal access"
    end
    @io.puts
  end

  def print_summary(result)
    @io.puts
    @io.puts "Eligible active facilitators: #{result.eligible_zero} in zero-cost orgs, #{result.eligible_standard} elsewhere"
    @io.puts "Created: #{result.created_zero} at $0, #{result.created_standard} at the standard fee"
    @io.puts "Skipped — already has a membership: #{result.skipped_existing.size}"
    @io.puts "Skipped — no portal access: #{result.no_access_count}"
    result.skipped_no_access.each { |reason, count| @io.puts "  - #{reason}: #{count}" }

    print_skipped_existing(result)
    print_review_fees(result)
    print_multi_org(result)
    print_failures(result)
  end

  def print_skipped_existing(result)
    return if result.skipped_existing.empty?

    @io.puts "Already-membership people (re-runs skip them):"
    result.skipped_existing.each do |skip|
      @io.puts "  - #{skip.person.id} #{skip.person.email}: #{membership_label(skip.memberships)}"
    end
  end

  def print_review_fees(result)
    return if result.review_fees.empty?

    @io.puts "In a zero-cost org but already has a non-$0 membership (reprice manually):"
    result.review_fees.each do |skip|
      @io.puts "  - #{skip.person.id} #{skip.person.email}: #{membership_label(skip.memberships)}"
    end
  end

  def print_multi_org(result)
    return if result.multi_org.empty?

    @io.puts "Zero-cost people who also facilitate elsewhere (priced at $0):"
    result.multi_org.each do |row|
      @io.puts "  * #{row.person.id} #{row.person.email}: orgs #{row.organization_ids.join(', ')}"
    end
  end

  def print_failures(result)
    return if result.failures.empty?

    @io.puts "Failures:"
    result.failures.each do |failure|
      @io.puts "  ! #{failure.person.id} #{failure.person.email}: #{failure.errors.to_sentence}"
    end
  end

  def membership_label(memberships)
    memberships.map do |membership|
      cost = membership.cost_cents.nil? ? "standard" : MoneyFormatter.dollars_from_cents(membership.cost_cents)
      "#{membership.start_date} – #{membership.end_date} (#{cost})"
    end.join("; ")
  end
end
