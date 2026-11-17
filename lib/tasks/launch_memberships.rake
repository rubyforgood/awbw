# frozen_string_literal: true

# Create the initial 3/1/2027 membership for every active facilitator with portal
# access (see Membership::LaunchSeed).
#
# ORG_IDS is the zero-cost set: people actively facilitating at any of those orgs get
# a membership locked at $0. Everyone else starts at the standard annual fee. The list
# is an input because "large enough to be free" fluctuates and is decided outside the
# importer.
#
# Eligibility is judged on the day the task runs, not on the future start date — we
# can't know who will still be an active facilitator on 3/1. Anyone who already has an
# unlocked membership is skipped and reported, so the task is safe to re-run.
#
# Dry-run by default.
#   ORG_IDS=12,45,88 bin/rails data:launch_memberships              # preview
#   DRY_RUN=false ORG_IDS=12,45,88 bin/rails data:launch_memberships  # create memberships
namespace :data do
  desc "Create 3/1/2027 memberships for active facilitators. ORG_IDS=1,2 (zero-cost orgs). Idempotent. DRY_RUN=false to execute."
  task launch_memberships: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    raw_ids = ENV.fetch("ORG_IDS", "").split(",").map(&:strip).reject(&:blank?)

    if raw_ids.empty?
      abort "ORG_IDS is required, e.g. ORG_IDS=12,45,88 bin/rails data:launch_memberships"
    end

    org_ids = raw_ids.map do |raw|
      Integer(raw)
    rescue ArgumentError
      abort "ORG_IDS must be a comma-separated list of numeric organization IDs (got #{raw.inspect})."
    end

    actor = Setting.import_user

    puts "Membership launch seed — #{dry_run ? 'DRY RUN (no writes)' : 'WRITE'}"
    puts "Zero-cost org IDs: #{org_ids.uniq.join(', ')}"
    puts "Created by: #{actor&.email || '(none — Setting.import_user is blank)'}"
    puts

    begin
      Membership::LaunchSeed.call(org_ids:, dry_run:, io: $stdout, actor:)
    rescue ArgumentError => e
      abort e.message
    end

    puts
    puts(dry_run ? "DRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "Done.")
  end
end
