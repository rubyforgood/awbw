# frozen_string_literal: true

namespace :fm do
  desc "Create portal registrations for the 2026 on-demand facilitator training. Idempotent. DRY_RUN=false to execute."
  task on_demand_2026: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    verbose = ENV["VERBOSE"] == "true"
    import_user = Setting.import_user
    abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

    payer_row_ids = %w[P78311 P78755 P78969].freeze
    partner_rate_cents = 5_000

    fm_event = FmEvent.find_by(fm_id: ENV["FM_EVENT_ID"].presence || "E4014") ||
      abort("No FileMaker event #{ENV["FM_EVENT_ID"].presence || "E4014"} in the archive.")
    year = fm_event.data["Year"].to_i
    event = if ENV["EVENT_ID"].present?
      Event.find_by(id: ENV["EVENT_ID"]) || abort("No event with id #{ENV["EVENT_ID"]}.")
    else
      Event.on_demand.facilitator_trainings.in_year(year).order(:start_date).first ||
        abort("No on-demand facilitator training for #{year} — set EVENT_ID.")
    end

    rows = FmParticipant.find_by_data("EventID", fm_event.fm_id).order(:fm_id).to_a
    staff = StaffTranslation.new

    report = []
    say = ->(line = "") { puts line; report << line }

    parse_time = ->(value) { Time.zone.parse(value.to_s) rescue nil }
    stamps = lambda do |data|
      {
        created_by_id: staff.user_id_for(data["EnteredBy"]) || import_user.id,
        updated_by_id: staff.user_id_for(data["ModifiedBy"]) || import_user.id
      }
    end
    notes_for = ->(data) { data["Notes"].to_s.squish }
    waived = ->(data) { notes_for.call(data).match?(/waiv/i) }
    list_rate = ->(data) { notes_for.call(data).match?(/\b750\b/) }
    fee_cents = ->(data) { (data["Fee"].to_s.to_d * 100).round }
    status_for = ->(data) { notes_for.call(data).match?(/complet/i) ? "attended" : "registered" }
    name_differs = lambda do |data, person|
      tokens = data["Name"].to_s.downcase.gsub(/[^a-z ]/, " ").split
      names = [ person.first_name, person.last_name ].compact.flat_map { |value| value.to_s.downcase.gsub(/[^a-z ]/, " ").split }
      tokens.any? && (tokens & names).empty?
    end
    preferred_person = lambda do |people|
      people.max_by { |candidate| [ User.where(person_id: candidate.id).exists? ? 1 : 0, candidate.affiliations.count, -candidate.id ] }
    end
    name_words = ->(value) { value.to_s.downcase.gsub(/[^a-z ]/, " ").split.to_set }
    same_human_people = lambda do |data, coded_people|
      emails = coded_people.flat_map { |candidate| [ candidate.email, candidate.email_2 ] }
        .compact_blank.map { |email| email.downcase.strip }.uniq
      if emails.empty?
        []
      else
        words = name_words.call(data["Name"]) | coded_people.flat_map { |candidate| name_words.call(candidate.full_name) }.to_set
        Person.where("LOWER(email) IN (?) OR LOWER(email_2) IN (?)", emails, emails)
          .where.not(id: coded_people.map(&:id))
          .select { |candidate| (name_words.call(candidate.full_name) & words).any? }
      end
    end
    name_key = ->(value) { value.to_s.downcase.gsub(/[^a-z]/, "") }

    name_index = EventRegistration.where(event_id: event.id).includes(:registrant).to_a
      .group_by { |registration| [ name_key.call(registration.registrant.first_name), name_key.call(registration.registrant.last_name) ] }

    discount_for = lambda do |data|
      if waived.call(data)
        event.cost_cents.to_i
      elsif list_rate.call(data)
        0
      else
        [ event.cost_cents.to_i - fee_cents.call(data), 0 ].max
      end
    end

    stopped = false
    created = []
    adopted = []
    skipped = []
    warnings = []
    multi_code = []
    failures = []

    say.("FileMaker #{fm_event.fm_id} — #{fm_event.data["Title"]}")
    say.("→ portal event ##{event.id} #{event.title} (#{event.start_date.to_date} – #{event.end_date.to_date})")
    say.("#{rows.size} archive row(s). #{dry_run ? "DRY RUN — nothing will be written." : "Importing."}")
    say.()

    Current.source = "fm_on_demand_2026"

    begin
      ActiveRecord::Base.transaction do
        rows.each do |row|
          data = row.data || {}
          name = data["Name"].to_s.squish.presence || row.fm_id

          if payer_row_ids.include?(row.fm_id)
            skipped << "  #{row.fm_id} #{name} — payer row, not a registrant"
            next
          end

          coded_people = Person.with_filemaker_code(data["ParticipantID"]).to_a
          if coded_people.empty?
            failures << "#{row.fm_id} #{name}: no person carries ParticipantID #{data["ParticipantID"].inspect}"
            next
          end

          person = preferred_person.call(coded_people)
          multi_code << [ data["ParticipantID"], coded_people, person ] if coded_people.size > 1
          warnings << "#{row.fm_id} #{name}: archive name does not match #{person.full_name}" if name_differs.call(data, person)

          status = status_for.call(data)
          existing = EventRegistration.with_filemaker_code(row.fm_id).first ||
            EventRegistration.find_by(event_id: event.id, registrant_id: person.id)
          lookalikes = []
          if existing.nil? && (same_human = same_human_people.call(data, coded_people)).any?
            candidates = EventRegistration
              .where(event_id: event.id, registrant_id: same_human.map(&:id), filemaker_code: nil).to_a
            if candidates.one?
              existing = candidates.first
              lookalikes = same_human
            elsif candidates.size > 1
              failures << "#{row.fm_id} #{name}: #{candidates.size} registrations share an email with this person " \
                          "(#{candidates.map { |candidate| "##{candidate.id} #{candidate.registrant.full_name}" }.join(", ")}) " \
                          "— left alone, resolve by hand"
              next
            end
          end

          if existing
            if existing.event_id != event.id
              failures << "#{row.fm_id} #{name}: already coded onto registration ##{existing.id} for another event"
              next
            end

            if existing.filemaker_codes.exclude?(row.fm_id)
              merged = EventRegistration.join_filemaker_codes(existing.filemaker_code, row.fm_id)
              existing.update_column(:filemaker_code, merged) unless dry_run
            end
            adopted << [ row, person, existing, status, lookalikes ]
            next
          end

          twins = (name_index[[ name_key.call(person.first_name), name_key.call(person.last_name) ]] || [])
            .reject { |registration| registration.registrant_id == person.id }
          if twins.any?
            warnings << "#{row.fm_id} #{name}: same name as #{twins.map { |registration| "##{registration.id} #{registration.registrant.full_name} (#{registration.registrant.preferred_email})" }.join(", ")} — different email, check they are not one person"
          end

          registration = EventRegistration.new(
            event: event,
            registrant: person,
            status: status,
            filemaker_code: row.fm_id,
            created_at: parse_time.call(data["DateEntered"]) || Time.current,
            updated_at: parse_time.call(data["DateTimeModified"]) || parse_time.call(data["DateEntered"]) || Time.current,
            **stamps.call(data)
          )

          if dry_run
            created << [ row, person, registration, discount_for.call(data) ]
            next
          end

          unless registration.save
            failures << "#{row.fm_id} #{name}: #{registration.errors.full_messages.to_sentence}"
            next
          end

          key = [ name_key.call(person.first_name), name_key.call(person.last_name) ]
          name_index[key] = Array(name_index[key]) + [ registration ]

          cents = discount_for.call(data)
          if cents.positive? && registration.allocations.where(source_type: "Discount").none?
            discount = Discount.new(amount_cents: cents, event: event, **stamps.call(data))
            if discount.save
              registration.allocations.create!(source: discount, amount: cents)
            else
              failures << "#{row.fm_id} #{name}: discount not saved — #{discount.errors.full_messages.to_sentence}"
            end
          end

          created << [ row, person, registration, cents ]
          say.("  #{row.fm_id} #{name.ljust(28)} #{status.ljust(9)} #{"discount #{MoneyFormatter.dollars_from_cents(cents)}" if cents.positive?}".rstrip) if verbose
        end

        say.("Created: #{created.size}, adopted: #{adopted.size}, payer rows skipped: #{skipped.size}, failed: #{failures.size}")
        say.("Discounts: #{created.count { |_r, _p, _reg, cents| cents.positive? }} totalling " \
             "#{MoneyFormatter.dollars_from_cents(created.sum { |_row, _person, _reg, cents| cents })}")

        say.()
        say.("--- Adopted (code written; everything else left alone) ---")
        say.("(none)") if adopted.empty?
        adopted.each do |row, person, existing, status, lookalikes|
          data = row.data || {}
          subject = existing.registrant
          if lookalikes.any?
            say.("#{row.fm_id} #{person.full_name} → registration ##{existing.id} (portal #{existing.status}) " \
                 "— held by person ##{subject.id} #{subject.full_name}, matched by email")
            lookalikes.reject { |candidate| candidate.id == subject.id }.each do |candidate|
              say.("    another record on this email: ##{candidate.id} #{candidate.full_name} — merge the people")
            end
          else
            say.("#{row.fm_id} #{person.full_name} → registration ##{existing.id} (portal #{existing.status})")
          end

          differences = []
          previous_codes = existing.filemaker_codes - [ row.fm_id ]
          differences << "filemaker code: already carried #{previous_codes.join(", ")}" if previous_codes.any?
          if existing.status != status
            differences << "status: archive #{status}#{" (#{notes_for.call(data)})" if notes_for.call(data).present?}, portal #{existing.status}"
          end
          registered_on = parse_time.call(data["DateEntered"])&.to_date
          if registered_on && existing.created_at.to_date != registered_on
            differences << "registered: archive #{registered_on}, portal #{existing.created_at.to_date}"
          end
          archive_money =
            if waived.call(data)
              "waived"
            elsif notes_for.call(data).match?(/paid/i)
              "#{MoneyFormatter.dollars_from_cents(fee_cents.call(data))} paid"
            else
              "nothing recorded"
            end
          portal_money = "#{MoneyFormatter.dollars_from_cents(existing.payments_sum)} paid, " \
                         "#{MoneyFormatter.dollars_from_cents(existing.discount_sum)} discounted, " \
                         "#{MoneyFormatter.dollars_from_cents(existing.remaining_cost)} due"
          money_differs = if archive_money == "nothing recorded"
            (existing.payments_sum.to_i + existing.discount_sum.to_i).positive?
          else
            !existing.paid_in_full?
          end
          differences << "money: archive #{archive_money}, portal #{portal_money}" if money_differs

          if differences.empty?
            say.("    no differences")
          else
            differences.each { |line| say.("    #{line}") }
          end
        end
        say.()

        say.("--- ParticipantID carried by more than one person ---")
        say.("(none)") if multi_code.empty?
        multi_code.each do |code, people, chosen|
          others = people - [ chosen ]
          login = User.where(person_id: chosen.id).exists? ? " (login)" : ""
          say.("#{code}: used ##{chosen.id} #{chosen.full_name}#{login}; also " \
               "#{others.map { |candidate| "##{candidate.id} #{candidate.full_name} (#{candidate.preferred_email})" }.join(", ")}")
        end
        say.()

        say.("--- Payer map (for the manual payment allocations) ---")
        say.("Seats per row's Fee; a group note naming fewer people than it bought leaves the rest to work out.")
        FmPayment.find_by_data("RefID", fm_event.fm_id).order(:fm_id).each do |payment|
          cents = (payment.data["Amount"].to_s.to_d * 100).round
          next unless cents > partner_rate_cents && cents != event.cost_cents.to_i

          payer = Person.with_filemaker_code(payment.data["RolodexID"]).first
          seats = (cents / partner_rate_cents.to_f).round(1)
          members = rows.select do |row|
            next false if payer_row_ids.include?(row.fm_id)

            note = notes_for.call(row.data || {})
            note.match?(/paid|document/i) && payer && (
              note.downcase.include?(payer.last_name.to_s.downcase) ||
              note.downcase.include?(payer.full_name.to_s.downcase)
            )
          end
          say.("#{payment.fm_id} #{MoneyFormatter.dollars_from_cents(cents)} — #{payer&.full_name || payment.data["RolodexID"]} (#{seats.to_i} seat(s) at #{MoneyFormatter.dollars_from_cents(partner_rate_cents)}, #{members.size} named)")
          note = payment.data["Note"].to_s.squish
          say.("  note: #{note.truncate(240)}") if note.present?
          members.each { |row| say.("  #{row.fm_id} #{row.data["Name"].to_s.squish}") }
        end
        say.()

        say.("--- Skipped ---")
        skipped.each { |line| say.(line) }
        say.("(none)") if skipped.empty?
        say.()

        say.("--- Unmatched FileMaker staff names ---")
        if staff.unmatched.any?
          staff.unmatched.each { |name, count| say.("#{name} (#{count})") }
        else
          say.("(none)")
        end
        say.()

        say.("--- Warnings ---")
        warnings.each { |message| say.("  #{message}") }
        say.("(none)") if warnings.empty?
        say.()

        say.("--- Failed ---")
        failures.each { |message| say.("  #{message}") }
        say.("(none)") if failures.empty?
        say.()

        raise ActiveRecord::Rollback if dry_run
      end
    rescue StandardError => e
      stopped = true
      say.("\nStopped by #{e.class}: #{e.message}")
      raise
    ensure
      say.("\nRolled back — nothing written. Fix the error and re-run.") if stopped
      say.(dry_run ? "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute." : "\nDone.") unless stopped
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(report.join("\n")), content_type: "text/plain",
          filename: "fm-on-demand-2026-#{Time.current.strftime("%Y%m%d-%H%M%S")}#{"-dry-run" if dry_run}.txt"
        )
        puts "\nReport saved. Read it back with: bin/rails runner 'puts ActiveStorage::Blob.find(#{blob.id}).download'"
      rescue StandardError => e
        puts "\nCould not save the report (#{e.class}: #{e.message}) — copy the output above."
      end
    end
  end
end
