# One-off: fold the draft March 2026 training (#19, TAC261) into the one its
# trainees are registered on (#2), so the money and the people share one event.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/merge_march_2026_events.rb
#   DRY_RUN=false bin/rails runner scripts/merge_march_2026_events.rb
#
# First merge people 36284 and 2811 in the people deduper. The emptied #19 is left
# for an admin to delete once #2 looks right. Re-running after it applies stops with
# nothing written.

dry_run = ENV["DRY_RUN"] != "false"

target_id = 2
draft_id = 19
price_cents = 150_000
abbreviation = "TAC261"

# draft registration => the same person's registration on the target
merges = {
  777 => 13, 813 => 64, 815 => 91, 816 => 77, 817 => 45,
  994 => 32, 1002 => 103, 1267 => 106, 1268 => 80, 1269 => 88
}.freeze
# Target registrations whose person transferred to the July training.
transferred_out = [ 13, 32 ].freeze
# Draft registrations with no counterpart on the target.
moves = [ 814, 818 ].freeze
submission_id = 599

import_user = Setting.import_user
abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

Current.user = import_user
Current.source = "merge_march_2026_events"

dollars = ->(cents) { MoneyFormatter.dollars_from_cents(cents) }
allocated_on = lambda do |registration_ids|
  Allocation.where(allocatable_type: "EventRegistration", allocatable_id: registration_ids).sum(:amount)
end
describe = lambda do |registration|
  "##{registration.id} event ##{registration.event_id} #{registration.status.ljust(15)} " \
    "covered #{dollars.call(registration.allocations_sum)}, due #{dollars.call(registration.remaining_cost)}"
end

problems = []
target = Event.find_by(id: target_id)
draft = Event.find_by(id: draft_id)
problems << "event ##{target_id} or ##{draft_id} is missing" unless target && draft

if problems.empty?
  problems << "##{draft_id} is not the unpublished #{abbreviation} draft" if draft.published? || draft.abbreviation != abbreviation
  problems << "##{target_id} already has a price (#{dollars.call(target.cost_cents)})" if target.cost_cents.to_i.positive?
  if target.starts_on != draft.starts_on
    problems << "##{target_id} starts #{target.starts_on}, ##{draft_id} starts #{draft.starts_on}"
  end

  expected = (merges.keys + moves).sort
  found = draft.event_registrations.order(:id).pluck(:id)
  if found != expected
    problems << "registrations on ##{draft_id} changed: unexpected #{found - expected}, missing #{expected - found}"
  end

  registrations = EventRegistration.where(id: merges.to_a.flatten + moves).index_by(&:id)
  merges.each do |draft_registration_id, target_registration_id|
    from = registrations[draft_registration_id]
    to = registrations[target_registration_id]
    if from.nil? || to.nil? || to.event_id != target_id
      problems << "pair #{draft_registration_id} → #{target_registration_id} not found on the expected events"
    elsif from.registrant_id != to.registrant_id
      problems << "pair #{draft_registration_id} → #{target_registration_id}: people ##{from.registrant_id} and " \
                  "##{to.registrant_id} — merge them in the people deduper first"
    end
  end
  moves.each do |id|
    registrant_id = registrations[id]&.registrant_id
    next unless registrant_id && target.event_registrations.exists?(registrant_id: registrant_id)

    problems << "registration ##{id}: its person is already on ##{target_id}"
  end

  target_allocated = allocated_on.call(target.event_registrations.select(:id))
  problems << "##{target_id} already holds #{dollars.call(target_allocated)}" unless target_allocated.zero?
  problems << "form submission ##{submission_id} is not on ##{draft_id}" unless draft.form_submissions.ids == [ submission_id ]
  unless target.registration_ticket_callouts.exists?(builtin_key: "payment")
    problems << "##{target_id} has no Payment callout row — open its edit page once to create it"
  end

  leftovers = {
    "discounts" => Discount.where(event_id: draft_id).count,
    "topic subscriptions" => TopicSubscription.where(interested_event_id: draft_id).count,
    "users' favorite event" => User.where(favorite_event_id: draft_id).count,
    "form completions" => FormCompletion.where(event_id: draft_id).count,
    "staff" => draft.event_staffs.count,
    "custom callouts" => draft.registration_ticket_callouts.where(builtin_key: nil).count,
    "bookmarks" => draft.bookmarks.count
  }.select { |_label, count| count.positive? }
  # Anything attached to the draft by type and id that this script doesn't move.
  ignored_tables = %w[ahoy_events versions action_text_rich_texts categorizable_items sectorable_items bookmarks]
  connection = ActiveRecord::Base.connection
  (connection.tables - ignored_tables).each do |table|
    columns = connection.columns(table).map(&:name)
    columns.grep(/_type\z/).each do |type_column|
      id_column = type_column.sub(/_type\z/, "_id")
      next unless columns.include?(id_column)

      count = Arel::Table.new(table).then do |arel|
        connection.select_value(arel.project(Arel.star.count).where(arel[type_column].eq("Event").and(arel[id_column].eq(draft_id))).to_sql)
      end
      leftovers["#{table} rows"] = count if count.positive?
    end
  end
  problems << "##{draft_id} also has #{leftovers.map { |label, count| "#{count} #{label}" }.to_sentence}" if leftovers.any?
end

if problems.any?
  puts "Stopped — nothing written:"
  problems.each { |problem| puts "  - #{problem}" }
  abort
end

puts dry_run ? "DRY RUN — everything below is rolled back.\n\n" : "APPLYING\n\n"

ActiveRecord::Base.transaction(requires_new: true) do
  deduper = ModelDeduper.new(model_class: EventRegistration, logger: Rails.logger, dry_run: false)
  total_before = allocated_on.call(draft.event_registrations.ids)
  july = EventRegistration.where(transferred_from_registration_id: draft.event_registrations.select(:id)).to_a
  july_before = july.to_h { |registration| [ registration.id, [ registration.allocations_sum, registration.remaining_cost ] ] }

  puts "Event ##{target_id}"
  draft_title = draft.title
  draft.update!(abbreviation: nil)
  target.update!(
    title: draft_title,
    abbreviation: abbreviation,
    cost_cents: price_cents,
    ce_hours_offered: target.ce_hours_offered || draft.ce_hours_offered,
    ce_hours_cost_cents: target.ce_hours_cost_cents || draft.ce_hours_cost_cents,
    # A past deadline keeps the new CE settings from inviting requests on old tickets.
    ce_hours_request_deadline: target.ce_hours_request_deadline || target.ends_on
  )
  target.saved_changes.except("updated_at", "updated_by_id").each do |column, (before, after)|
    puts "  #{column}: #{before.inspect} → #{after.inspect}"
  end

  # Hidden until everyone's payment is recorded, so tickets don't ask them for the new price.
  payment_callout = target.registration_ticket_callouts.find_by!(builtin_key: "payment")
  puts "  Payment callout on tickets: #{payment_callout.hidden? ? "already hidden" : "hidden"}"
  payment_callout.update!(hidden: true)

  draft.event_forms.bulk_payment.each do |link|
    next if target.event_forms.bulk_payment.exists?

    target.event_forms.create!(form_id: link.form_id, role: link.role)
    puts "  bulk payment form ##{link.form_id} linked"
  end

  puts "\nMerged into the registration already on ##{target_id}"
  merges.each do |draft_registration_id, target_registration_id|
    from = EventRegistration.find(draft_registration_id)
    to = EventRegistration.find(target_registration_id)
    unhandled = deduper.unhandled_references(from)
    raise "##{from.id} is still referenced by #{unhandled.pluck(:table).uniq.to_sentence}" if unhandled.any?

    %w[intends_to_pay scholarship_requested someone_else_will_pay invoice_requested w9_requested shoutout].each do |flag|
      to[flag] ||= from[flag]
    end
    %w[expected_payment_method fee_note].each { |column| to[column] = to[column].presence || from[column] }
    (%w[certificate_sent_at post_survey_completed_at checkout_session_id] + EventRegistration::DAY_FIELDS).each do |column|
      to[column] = from[column] if to[column].blank?
    end
    to.payment_unresolved = from.payment_unresolved if to.payment_unresolved.nil?
    to.filemaker_code = EventRegistration.join_filemaker_codes(to.filemaker_code, from.filemaker_code)
    changed = to.changes.except("updated_at", "updated_by_id")

    deduper.merge(to, from)
    to.scholarships.where.not(recipient_id: to.registrant_id).find_each { |scholarship| scholarship.update!(recipient: to.registrant) }
    EventRegistrationServices::ReconcileMergedContinuingEducation.new(to).call
    to.status = "transferred_out" if transferred_out.include?(to.id)
    to.save!
    if transferred_out.include?(to.id) && from.status_before_transfer.present?
      to.update!(status_before_transfer: from.status_before_transfer)
    end

    to = EventRegistration.find(to.id)
    puts "  ##{draft_registration_id} → #{describe.call(to)}#{" #{changed.keys.to_sentence} carried over" if changed.any?}"
  end

  puts "\nMoved to ##{target_id}"
  moves.each do |id|
    EventRegistration.find(id).update!(event: target)
    puts "  #{describe.call(EventRegistration.find(id))}"
  end

  FormSubmission.find(submission_id).update!(event: target)
  puts "  form submission ##{submission_id}"

  # Bulk payment submissions name the registrations they cover by id in metadata.
  FormSubmission.where(role: "bulk_payment").find_each do |submission|
    linked_ids = submission.linked_registration_ids
    remapped = linked_ids.map { |id| merges.fetch(id, id) }.uniq
    next if remapped == linked_ids

    submission.update!(metadata: submission.metadata.merge("linked_registration_ids" => remapped))
    puts "  submission ##{submission.id} people: #{linked_ids.inspect} → #{remapped.inspect}"
  end

  puts "\nTheir July registrations"
  EventRegistration.where(id: july.map(&:id)).order(:id).each do |registration|
    puts "  #{describe.call(registration)}, from ##{registration.transferred_from_registration_id}"
    if july_before[registration.id] != [ registration.allocations_sum, registration.remaining_cost ]
      raise "July registration ##{registration.id}'s balance changed"
    end
  end

  kept_ids = merges.values + moves
  total_after = allocated_on.call(kept_ids)
  raise "money changed: #{dollars.call(total_before)} before, #{dollars.call(total_after)} after" if total_before != total_after
  raise "##{draft_id} still has registrations" if EventRegistration.exists?(event_id: draft_id)
  if (over = EventRegistration.where(id: kept_ids).select(&:over_allocated?)).any?
    raise "over-allocated: #{over.map(&:id).to_sentence}"
  end

  linked = Affiliation.where(event_registration_id: transferred_out).pluck(:id, :event_registration_id)
  owing = EventRegistration.where(event_id: target_id).active.reject(&:paid_in_full?)
  puts "\nMoney moved: #{dollars.call(total_after)}"
  puts "Now owing on ##{target_id}: #{owing.size} people, #{dollars.call(owing.sum(&:remaining_cost))}"
  puts "Affiliations still tied to the transferred-out registrations: #{linked.presence&.inspect || "none"}"

  left = Event.find(draft_id)
  puts "\nNot copied — goes when ##{draft_id} is deleted"
  puts "  callouts: #{left.registration_ticket_callouts.map(&:title).to_sentence.presence || "none"}"
  puts "  form links: #{left.event_forms.includes(:form).map { |link| "#{link.role} (#{link.form.name})" }.to_sentence.presence || "none"}"
  puts "  tags: #{left.categorizable_items.count + left.sectorable_items.count}, " \
       "page text: #{[ left.rhino_header, left.rhino_description ].sum { |text| text.to_plain_text.strip.length }} characters"

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "\nDone. Check ##{target_id}, then delete ##{draft_id} in the portal."
