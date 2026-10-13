# frozen_string_literal: true

# Create a 2/1/2027 membership for every person with an active facilitator
# affiliation, priced by the size of the org they facilitate at:
#   bucket 1 (1 active facilitator)  -> app-wide default (Membership::ANNUAL_COST_CENTS)
#   bucket 2-3 (2-3 facilitators)    -> $50/yr
#   bucket 4+ (4+ facilitators)      -> $20/yr
#
# A facilitator active at orgs spanning multiple buckets is priced at their
# largest bucket and listed for review. People without an active user account
# (or none at all) and people who already hold an uncancelled membership are
# skipped and reported so they can be followed up.
#
# Dry-run by default; DRY_RUN=false to write. Idempotent: anyone who already
# has an uncancelled membership is skipped.
#   bin/rails data:create_facilitator_memberships              # preview, writes nothing
#   DRY_RUN=false bin/rails data:create_facilitator_memberships  # create memberships
namespace :data do
  desc "Create 2/1/2027 memberships for all active facilitators. Idempotent. DRY_RUN=false to execute."
  task create_facilitator_memberships: :environment do
    dry_run = ENV["DRY_RUN"] != "false"

    covering = Date.new(2027, 2, 1)
    bucket_23_cost_cents = 5_000
    bucket_4plus_cost_cents = 2_000

    bucket_for = lambda do |count|
      case count
      when 1 then 1
      when 2..3 then 2
      else 3
      end
    end
    bucketed_cost_cents = lambda do |bucket|
      case bucket
      when 2 then bucket_23_cost_cents
      when 3 then bucket_4plus_cost_cents
      end
    end

    # org_id => number of distinct active facilitators (drives the bucket).
    org_counts = Affiliation.facilitators.active
      .group(:organization_id)
      .distinct
      .count(:person_id)
    bucket_by_org = org_counts.transform_values { |count| bucket_for.(count) }

    # person_id => the buckets of every org they actively facilitate at.
    person_org_buckets = Hash.new { |hash, person_id| hash[person_id] = [] }
    Affiliation.facilitators.active.pluck(:person_id, :organization_id).each do |person_id, org_id|
      person_org_buckets[person_id] << bucket_by_org[org_id]
    end

    people = Person.where(id: person_org_buckets.keys)
      .includes(:user)
      .order(:last_name, :first_name)

    created = Hash.new(0)
    skipped_no_user = Hash.new(0)
    skipped_membership = 0
    multi_bucket = []

    ActiveRecord::Base.transaction do
      people.each do |person|
        buckets = person_org_buckets[person.id].uniq
        bucket = buckets.max
        multi_bucket << [ person, buckets ] if buckets.size > 1

        if person.memberships.autorenewal_not_cancelled.exists?
          skipped_membership += 1
          puts "  - #{person.id} #{person.full_name}: already has an uncancelled membership — skipped"
          next
        end

        reason = missing_account_reason(person)
        if reason
          skipped_no_user[reason] += 1
          puts "  ! #{person.id} #{person.full_name} (org bucket #{bucket}): no active user account (#{reason}) — skipped"
          next
        end

        cost_cents = bucketed_cost_cents.(bucket)
        membership = person.memberships.create!(cost_cents: cost_cents)
        Membership::EnsureInvoice.call(membership: membership, covering: covering)
        created[bucket] += 1
        puts "  + #{person.id} #{person.full_name}: bucket #{bucket}, #{MoneyFormatter.dollars_from_cents(membership.cost_cents || Membership::ANNUAL_COST_CENTS)} (#{covering.iso8601})"
      end

      raise ActiveRecord::Rollback if dry_run
    end

    puts
    puts "buckets 1:          #{created[1]}"
    puts "buckets 2-3:        #{created[2]}"
    puts "buckets 4+:         #{created[3]}"
    puts "skipped no account: #{skipped_no_user.sum { |_, count| count }}"
    skipped_no_user.each { |reason, count| puts "  - #{reason}: #{count}" }
    puts "skipped (has membership): #{skipped_membership}"
    if multi_bucket.any?
      puts "multi-bucket people (priced at largest bucket):"
      multi_bucket.each do |person, buckets|
        puts "  * #{person.id} #{person.full_name}: buckets #{buckets.join(', ')}"
      end
    end
    puts(dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "\nDone.")
  end
end

# Why this person can't sign in (User#has_access? :: user must exist, be
# confirmed, not locked and not inactive); nil means they have an active account.
def missing_account_reason(person)
  user = person.user
  return "no user account" if user.nil?
  return "inactive" if user.inactive?
  return "locked" if user.locked_at.present?
  return "unconfirmed" if user.confirmed_at.nil?

  nil
end
