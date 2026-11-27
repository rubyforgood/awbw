# One-off, part 1 of 2: move the March 2026 registrations from #2 onto the TAC261
# event that holds the money (#19). The other part,
# merge_march_2026_event_settings.rb, carries #2's page and ticket settings over;
# run that one first, then this one.
#
# No allocation moves: #19's registrations keep their own, and #2's have none.
# Registrations for someone already on #19 merge into theirs; the rest move.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/merge_march_2026_registrations.rb
#   DRY_RUN=false bin/rails runner scripts/merge_march_2026_registrations.rb
#
# First merge people 2811 and 36284 in the people deduper. Re-running after it
# applies stops with nothing written.

dry_run = ENV["DRY_RUN"] != "false"

source_id = 2
target_id = 19
abbreviation = "TAC261"

# Registration on #2 => the same person's registration on #19, which is kept.
merges = {
  13 => 777, 64 => 813, 91 => 815, 77 => 816, 45 => 817,
  32 => 994, 103 => 1002, 106 => 1267, 80 => 1268, 88 => 1269
}.freeze
# #19's registrations with no counterpart on #2.
target_only = [ 814, 818 ].freeze
# Fields a merge fills on the kept registration when it has none.
filled_columns = (%w[
  expected_payment_method fee_note certificate_sent_at post_survey_completed_at checkout_session_id
] + EventRegistration::DAY_FIELDS).freeze
merged_flags = %w[intends_to_pay scholarship_requested someone_else_will_pay invoice_requested w9_requested shoutout].freeze
# Registrant records tied to the event itself; nothing here moves them.
empty_on_source = {
  "form submissions" => ->(id) { FormSubmission.where(event_id: id) },
  "form completions" => ->(id) { FormCompletion.where(event_id: id) },
  "discounts" => ->(id) { Discount.where(event_id: id) }
}.freeze

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = "merge_march_2026_registrations"

dollars = ->(cents) { MoneyFormatter.dollars_from_cents(cents) }
describe = lambda do |registration|
  "##{registration.id} #{registration.status.ljust(15)} " \
    "covered #{dollars.call(registration.allocations_sum)}, due #{dollars.call(registration.remaining_cost)}"
end
allocations_for = lambda do |registration_ids|
  ce_ids = ContinuingEducationRegistration.where(event_registration_id: registration_ids).select(:id)
  Allocation.where(allocatable_type: "EventRegistration", allocatable_id: registration_ids)
    .or(Allocation.where(allocatable_type: "ContinuingEducationRegistration", allocatable_id: ce_ids))
    .order(:id).pluck(:id, :allocatable_type, :allocatable_id, :amount)
end

problems = []
source = Event.find_by(id: source_id)
target = Event.find_by(id: target_id)
problems << "event ##{source_id} or ##{target_id} is missing" unless source && target

if problems.empty?
  problems << "##{target_id} is not #{abbreviation}" if target.abbreviation != abbreviation
  problems << "##{source_id} starts #{source.starts_on}, ##{target_id} starts #{target.starts_on}" if source.starts_on != target.starts_on
  problems << "##{target_id} has no price" unless target.cost_cents.to_i.positive?

  source_registrations = source.event_registrations.to_a
  problems << "##{source_id} has no registrations left to move" if source_registrations.empty?
  money_on_source = allocations_for.call(source_registrations.map(&:id))
  problems << "##{source_id}'s registrations hold #{money_on_source.size} allocation(s)" if money_on_source.any?

  by_id = EventRegistration.where(id: merges.to_a.flatten).index_by(&:id)
  merges.each do |from_id, to_id|
    from = by_id[from_id]
    to = by_id[to_id]
    if from&.event_id != source_id || to&.event_id != target_id
      problems << "pair #{from_id} → #{to_id} not found on the expected events"
    elsif from.registrant_id != to.registrant_id
      problems << "pair #{from_id} → #{to_id}: people ##{from.registrant_id} and ##{to.registrant_id} " \
                  "— merge them in the people deduper first"
    end
  end
  target_people = target.event_registrations.where.not(id: merges.values).pluck(:registrant_id)
  clashes = source_registrations.reject { |registration| merges.key?(registration.id) }
    .select { |registration| target_people.include?(registration.registrant_id) }
  problems << "registrations #{clashes.map(&:id)} have a person already on ##{target_id}" if clashes.any?
  if (extra = target.event_registrations.where.not(id: merges.values + target_only).ids).any?
    problems << "new registrations on ##{target_id}: #{extra}"
  end

  # Bulk payments name the registrations they cover by id; the merge deletes #2's copies.
  named = FormSubmission.where(role: "bulk_payment").select { |submission| (submission.linked_registration_ids & merges.keys).any? }
  problems << "bulk payments #{named.map(&:id)} name registrations this merge deletes" if named.any?

  empty_on_source.each do |label, scope|
    count = scope.call(source_id).count
    problems << "##{source_id} has #{count} #{label}" if count.positive?
  end
end

if problems.any?
  puts "Stopped — nothing written:"
  problems.each { |problem| puts "  - #{problem}" }
  abort
end

puts dry_run ? "DRY RUN — everything below is rolled back.\n\n" : "APPLYING\n\n"

ActiveRecord::Base.transaction(requires_new: true) do
  deduper = ModelDeduper.new(model_class: EventRegistration, logger: Rails.logger, dry_run: false)
  kept_ids = target.event_registrations.ids
  money_before = allocations_for.call(kept_ids)
  july = EventRegistration.where(transferred_from_registration_id: kept_ids).to_a
  july_before = july.to_h { |registration| [ registration.id, [ registration.allocations_sum, registration.remaining_cost ] ] }

  puts "Merged into ##{target_id}'s registration"
  merges.each do |from_id, to_id|
    from = EventRegistration.find(from_id)
    to = EventRegistration.find(to_id)
    unhandled = deduper.unhandled_references(from)
    raise "##{from.id} is still referenced by #{unhandled.pluck(:table).uniq.to_sentence}" if unhandled.any?

    merged_flags.each { |flag| to[flag] ||= from[flag] }
    filled_columns.each { |column| to[column] = from[column] if to[column].blank? }
    to.payment_unresolved = from.payment_unresolved if to.payment_unresolved.nil?
    to.status = from.status if to.status == "registered" && !from.status.in?(%w[registered transferred_out])
    to.filemaker_code = EventRegistration.join_filemaker_codes(to.filemaker_code, from.filemaker_code)
    # Their ticket link went out by email from #2, so the kept registration answers to it.
    slug = from.slug
    created = [ from.created_at, to.created_at ].min
    created_by_id = from.created_by_id || to.created_by_id

    deduper.merge(to, from)
    to.scholarships.where.not(recipient_id: to.registrant_id).find_each { |scholarship| scholarship.update!(recipient: to.registrant) }
    EventRegistrationServices::ReconcileMergedContinuingEducation.new(to).call
    to.slug = slug
    to.save!
    to.update_columns(created_at: created, created_by_id: created_by_id)

    puts "  ##{from_id} → #{describe.call(EventRegistration.find(to_id))}"
  end

  moving = source.event_registrations.reload.to_a
  moving.each { |registration| registration.update!(event: target) }
  puts "\nMoved to ##{target_id}: #{moving.size} registrations"
  moving.group_by(&:status).each { |status, group| puts "  #{status}: #{group.size}" }

  puts "\nJuly registrations transferred from ##{target_id}"
  EventRegistration.where(id: july.map(&:id)).order(:id).each do |registration|
    puts "  #{describe.call(registration)}, from ##{registration.transferred_from_registration_id}"
    raise "##{registration.id}'s balance changed" if july_before[registration.id] != [ registration.allocations_sum, registration.remaining_cost ]
  end

  raise "##{source_id} still has registrations" if EventRegistration.exists?(event_id: source_id)
  raise "an allocation changed" if allocations_for.call(kept_ids) != money_before
  over = target.event_registrations.reload.select(&:over_allocated?)
  raise "over-allocated: #{over.map(&:id).to_sentence}" if over.any?

  owing = target.event_registrations.active.reject(&:paid_in_full?)
  puts "\nMoney on ##{target_id}, unchanged: #{dollars.call(money_before.sum(&:last))}"
  puts "Now owing on ##{target_id}: #{owing.size} people, #{dollars.call(owing.sum(&:remaining_cost))}"

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "\nDone. Check ##{target_id}'s registrants."
