# One-off: fold the original March 2026 training (#2) into the TAC261 event
# that holds the money (#19), so the people and their payments share one event.
# No allocation moves: #19's registrations keep their own, and #2's have none.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/merge_march_2026_events.rb
#   DRY_RUN=false bin/rails runner scripts/merge_march_2026_events.rb
#
# First merge people 2811 and 36284 in the people deduper. #2 is left
# unpublished and empty for an admin to delete. Re-running after it applies
# stops with nothing written.

dry_run = ENV["DRY_RUN"] != "false"

source_id = 2
target_id = 19
abbreviation = "TAC261"

# Registration on #2 => the same person's registration on #19, which is kept.
merges = {
  13 => 777, 64 => 813, 91 => 815, 77 => 816, 45 => 817,
  32 => 994, 103 => 1002, 106 => 1267, 80 => 1268, 88 => 1269
}.freeze

# #19 keeps its own name, price, CE settings and audit stamps; the rest comes from #2.
target_columns = %w[
  id title abbreviation cost_cents ce_hours_offered ce_hours_cost_cents ce_hours_request_deadline
  ce_payment_due_deadline ce_timesheets_enabled ce_timesheet_opens_offset_minutes ce_timesheet_closes_at
  discount_code discount_amount_cents affiliations_reconciled_at created_at created_by_id updated_at updated_by_id
].freeze
# Registration fields a merge fills on the kept registration when it has none.
filled_columns = (%w[
  expected_payment_method fee_note certificate_sent_at post_survey_completed_at checkout_session_id
] + EventRegistration::DAY_FIELDS).freeze
merged_flags = %w[intends_to_pay scholarship_requested someone_else_will_pay invoice_requested w9_requested shoutout].freeze
# Event-linked records that must be empty on #2; nothing here moves them.
empty_on_source = {
  "form submissions" => ->(id) { FormSubmission.where(event_id: id) },
  "form completions" => ->(id) { FormCompletion.where(event_id: id) },
  "discounts" => ->(id) { Discount.where(event_id: id) },
  "staff" => ->(id) { EventStaff.where(event_id: id) },
  "topic subscriptions" => ->(id) { TopicSubscription.where(interested_event_id: id) }
}.freeze
# Records attached to an event by type and id that this script moves or keeps as history.
handled_tables = %w[
  ahoy_events versions action_text_rich_texts assets categorizable_items sectorable_items bookmarks forms
].freeze

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = "merge_march_2026_events"

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
  problems << "##{target_id} is not the unpublished #{abbreviation} draft" if target.published? || target.abbreviation != abbreviation
  problems << "##{source_id} is not published" unless source.published?
  problems << "##{source_id} starts #{source.starts_on}, ##{target_id} starts #{target.starts_on}" if source.starts_on != target.starts_on
  problems << "##{target_id} has no price" unless target.cost_cents.to_i.positive?

  source_registrations = source.event_registrations.to_a
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
  if (extra = target.event_registrations.where.not(id: merges.values + [ 814, 818 ]).ids).any?
    problems << "new registrations on ##{target_id}: #{extra}"
  end

  empty_on_source.each do |label, scope|
    count = scope.call(source_id).count
    problems << "##{source_id} has #{count} #{label}" if count.positive?
  end
  connection = ActiveRecord::Base.connection
  (connection.tables - handled_tables).each do |table|
    columns = connection.columns(table).map(&:name)
    columns.grep(/_type\z/).each do |type_column|
      id_column = type_column.sub(/_type\z/, "_id")
      next unless columns.include?(id_column)

      arel = Arel::Table.new(table)
      sql = arel.project(Arel.star.count).where(arel[type_column].eq("Event").and(arel[id_column].eq(source_id))).to_sql
      count = connection.select_value(sql).to_i
      problems << "##{source_id} has #{count} #{table} row(s)" if count.positive?
    end
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

  puts "Event ##{target_id} takes from ##{source_id}"
  (Event.column_names - target_columns).each do |column|
    value = source[column]
    next if value.nil? || value == ""

    target[column] = value
  end
  # A past deadline keeps CE from inviting new requests on these tickets.
  target.ce_hours_request_deadline ||= source.ends_on
  target.save!
  target.saved_changes.except("updated_at", "updated_by_id").each do |column, (before, after)|
    puts "  #{column}: #{before.inspect.truncate(60)} → #{after.inspect.truncate(60)}"
  end
  source.update!(published: false)
  puts "  ##{source_id} unpublished"

  %w[rhino_header rhino_description].each do |name|
    from = ActionText::RichText.find_by(record: source, name: name)
    next if from.nil? || from.body.blank?

    existing = ActionText::RichText.find_by(record: target, name: name)
    if existing&.body.present?
      puts "  #{name}: ##{target_id} already has text, kept"
      next
    end
    existing&.destroy!
    from.update!(record: target)
    puts "  #{name} moved"
  end

  moved_assets = Asset.where(owner: source).update_all(owner_id: target_id)
  puts "  #{moved_assets} image(s) moved"
  owned_forms = Form.where(owner: source).update_all(owner_id: target_id)
  puts "  #{owned_forms} event-owned form(s) moved" if owned_forms.positive?
  [ [ source.categorizable_items, :categorizable, :category_id ], [ source.sectorable_items, :sectorable, :sector_id ] ].each do |items, owner, key|
    items.to_a.each do |item|
      item.class.exists?(owner => target, key => item[key]) ? item.destroy! : item.update!(owner => target)
    end
  end
  Bookmark.where(bookmarkable: source).update_all(bookmarkable_id: target_id)
  User.where(favorite_event_id: source_id).update_all(favorite_event_id: target_id)

  source.event_forms.each do |link|
    if target.event_forms.exists?(role: link.role)
      puts "  #{link.role} form ##{link.form_id}: ##{target_id} has its own, kept"
    else
      link.update!(event: target)
      puts "  #{link.role} form ##{link.form_id} moved"
    end
  end

  # Tickets show the callouts #2's registrants saw, unless #19's copy carries forms or resources.
  puts "\nTicket callouts"
  source.registration_ticket_callouts.to_a.each do |callout|
    mine = callout.builtin_key && target.registration_ticket_callouts.find_by(builtin_key: callout.builtin_key)
    if mine && (mine.registration_ticket_callout_forms.any? || mine.registration_ticket_callout_resources.any?)
      puts "  #{callout.title}: kept ##{target_id}'s (it has forms or resources)"
      next
    end

    mine&.destroy!
    callout.update!(event: target)
    puts "  #{callout.title}: ##{source_id}'s#{" replaces ##{target_id}'s" if mine}"
  end
  payment_callout = target.registration_ticket_callouts.reload.find_by(builtin_key: "payment")
  raise "##{target_id} has no Payment callout row — open its edit page once to create it" unless payment_callout

  # Hidden until everyone's payment is recorded, so tickets don't ask them for the price.
  payment_callout.update!(hidden: true)
  puts "  Payment: hidden"

  puts "\nMerged into ##{target_id}'s registration"
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
    to.skip_cancellation_emails = true
    to.save!
    to.update_columns(created_at: created, created_by_id: created_by_id)

    puts "  ##{from_id} → #{describe.call(EventRegistration.find(to_id))}"
  end

  FormSubmission.where(role: "bulk_payment").find_each do |submission|
    linked_ids = submission.linked_registration_ids
    remapped = linked_ids.map { |id| merges.fetch(id, id) }.uniq
    next if remapped == linked_ids

    submission.update!(metadata: submission.metadata.merge("linked_registration_ids" => remapped))
    puts "  bulk payment ##{submission.id} people: #{linked_ids.inspect} → #{remapped.inspect}"
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

  left = Event.find(source_id)
  puts "\nLeft on ##{source_id} — goes when it's deleted"
  puts "  callouts: #{left.registration_ticket_callouts.map(&:title).to_sentence.presence || "none"}"
  puts "  form links: #{left.event_forms.includes(:form).map { |link| "#{link.role} (#{link.form.name})" }.to_sentence.presence || "none"}"

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "\nDone. Check ##{target_id}, then delete ##{source_id} in the portal."
