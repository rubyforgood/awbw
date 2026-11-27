# One-off, one of two: give the TAC261 event (#19) the page and ticket settings
# the March 2026 registrants saw on #2, then unpublish #2. Runs before or after
# merge_march_2026_registrations.rb; neither depends on the other.
#
# #19 keeps its name, price and CE settings. #2's description, images, tags,
# forms and ticket callouts move over where #19 lacks them.
#
# Dry run by default: does everything, prints it, rolls back.
#
#   bin/rails runner scripts/merge_march_2026_event_settings.rb
#   DRY_RUN=false bin/rails runner scripts/merge_march_2026_event_settings.rb
#
# Once both have run, an admin deletes #2. Re-running after it applies stops
# with nothing written.

dry_run = ENV["DRY_RUN"] != "false"

source_id = 2
target_id = 19
abbreviation = "TAC261"

# #19 keeps its own name, price, CE settings and audit stamps; the rest comes from #2.
target_columns = %w[
  id title abbreviation cost_cents ce_hours_offered ce_hours_cost_cents ce_hours_request_deadline
  ce_payment_due_deadline ce_timesheets_enabled ce_timesheet_opens_offset_minutes ce_timesheet_closes_at
  discount_code discount_amount_cents affiliations_reconciled_at created_at created_by_id updated_at updated_by_id
].freeze
# Event-level records that must be empty on #2; nothing here moves them.
empty_on_source = {
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
Current.source = "merge_march_2026_event_settings"

problems = []
source = Event.find_by(id: source_id)
target = Event.find_by(id: target_id)
problems << "event ##{source_id} or ##{target_id} is missing" unless source && target

if problems.empty?
  problems << "##{target_id} is not the unpublished #{abbreviation} draft" if target.published? || target.abbreviation != abbreviation
  problems << "##{source_id} is not published" unless source.published?
  problems << "##{source_id} starts #{source.starts_on}, ##{target_id} starts #{target.starts_on}" if source.starts_on != target.starts_on

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

  # The 10 people registered on both signed up on #2 in February; #19's copies date from later.
  registered_at = {
    777 => "2026-02-27 21:51:59", 994 => "2026-02-28 00:27:44", 817 => "2026-02-28 13:53:37",
    813 => "2026-03-01 02:40:43", 816 => "2026-03-01 17:49:03", 1268 => "2026-03-01 17:55:34",
    1269 => "2026-03-01 19:03:39", 815 => "2026-03-01 19:12:14", 1002 => "2026-03-01 20:05:17",
    1267 => "2026-03-01 20:13:37"
  }.freeze
  registered_at.each do |id, utc|
    target.event_registrations.find(id).update_columns(created_at: Time.find_zone("UTC").parse(utc))
  end
  puts "  #{registered_at.size} registrations take their #2 sign-up dates"

  # Editor leftovers like "<p><br></p>" count as empty; text or an embedded image counts.
  written = ->(rich_text) { rich_text && (rich_text.to_plain_text.strip.present? || rich_text.body.attachables.any?) }
  %w[rhino_header rhino_description].each do |name|
    from = ActionText::RichText.find_by(record: source, name: name)
    next unless written.call(from)

    existing = ActionText::RichText.find_by(record: target, name: name)
    if written.call(existing)
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

  # Per built-in, the copy linking more forms and resources wins; a tie goes to #2's,
  # which its registrants saw.
  links = ->(callout) { callout.registration_ticket_callout_forms.count + callout.registration_ticket_callout_resources.count }
  puts "\nTicket callouts"
  source.registration_ticket_callouts.to_a.each do |callout|
    mine = callout.builtin_key && target.registration_ticket_callouts.find_by(builtin_key: callout.builtin_key)
    if mine && links.call(mine) > links.call(callout)
      puts "  #{callout.title}: kept ##{target_id}'s (#{links.call(mine)} forms/resources vs #{links.call(callout)})"
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

  left = Event.find(source_id)
  puts "\nLeft on ##{source_id} — goes when it's deleted"
  puts "  callouts: #{left.registration_ticket_callouts.map(&:title).to_sentence.presence || "none"}"
  puts "  form links: #{left.event_forms.includes(:form).map { |link| "#{link.role} (#{link.form.name})" }.to_sentence.presence || "none"}"

  Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
  raise ActiveRecord::Rollback if dry_run
end

puts dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to apply." : "\nDone. Check ##{target_id}'s page and tickets."
