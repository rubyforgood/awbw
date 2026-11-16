# frozen_string_literal: true

# Create portal payments for the 2026 FileMaker payment archive rows that have no
# portal record yet, and add the FileMaker code(s) to the portal payments the other
# rows already match. Idempotent: re-running creates nothing twice.
#
#   bin/rails fm:payments_2026                 # dry run, prints the plan
#   DRY_RUN=false bin/rails fm:payments_2026   # create the records
namespace :fm do
  desc "Create portal payments from 2026 FileMaker archive rows. Idempotent. DRY_RUN=false to execute."
  task payments_2026: :environment do
    dry_run = ENV["DRY_RUN"] != "false"
    import_user = Setting.import_user
    abort "No import user chosen — pick one on /admin/settings (Imports)." unless import_user

    start_date = Date.new(2026, 1, 1)
    end_date = Date.new(2027, 1, 1)

    # One FileMaker row paid for several people under a single charge.
    grouped_payments = [
      { ids: %w[D29114 D29115 D29116], amount_cents: 15_000 },
      { ids: %w[D29149 D29150], amount_cents: 24_000 },
      { ids: %w[D29151 D29152], amount_cents: 300_000 },
      { ids: %w[D29156 D29157], amount_cents: 10_000 },
      { ids: %w[D29162 D29163], amount_cents: 10_000 },
      { ids: %w[D29173 D29174], amount_cents: 250_000 }
    ].freeze

    # One FileMaker row, four instalments: the first is already in the portal.
    installments = [
      [ Date.new(2026, 6, 23), 21_800, 2 ],
      [ Date.new(2026, 7, 12), 21_800, 3 ],
      [ Date.new(2026, 7, 18), 21_800, 4 ]
    ].freeze
    installment_fm_id = "D29209"

    # Rows already accounted for: internal duplicates and a zero-amount placeholder.
    skip_fm_ids = %w[D29122 D29126 D29128 D29171 D29133 D29195].freeze

    # Rows matched by hand rather than by the rules below.
    verified_matches = {
      "D29177" => 34, "D29178" => 33, "D29179" => 32, "D29198" => 23, "D29216" => 65,
      "D29228" => 118, "D29230" => 119, "D29236" => 143, "D29240" => 167, "D29246" => 209,
      "D29247" => 216, "D29248" => 219, "D29250" => 228, "D29251" => 229,
      "D29190" => 25, "D29191" => 25, "D29212" => 8, "D29213" => 8, "D29218" => 68
    }.freeze

    # Archive rows that describe the same payment: the portal record gets every code.
    code_families = [
      %w[D29121 D29122],
      %w[D29125 D29126],
      %w[D29127 D29128],
      %w[D29170 D29171],
      %w[D29104 D29133]
    ].freeze
    codes_for = lambda do |fm_id|
      code_families.find { |family| family.include?(fm_id) } || [ fm_id ]
    end

    fm_rows = FmPayment.where(
      "JSON_UNQUOTE(JSON_EXTRACT(data,'$.DateReceived')) >= ? AND " \
      "JSON_UNQUOTE(JSON_EXTRACT(data,'$.DateReceived')) < ?",
      start_date, end_date
    ).to_a

    stripe_charge = ->(payment) { (payment.metadata || {})["stripe_charge"] || {} }
    charge_date = lambda do |payment|
      created = stripe_charge.call(payment)["created"]
      created ? Time.at(created.to_i).to_date : payment.created_at.to_date
    end
    charge_ids = lambda do |payment|
      charge = stripe_charge.call(payment)
      [ payment.stripe_charge_id, charge["id"], charge["payment_intent"], charge["balance_transaction"] ]
        .compact.map(&:to_s)
    end
    charge_emails = lambda do |payment|
      charge = stripe_charge.call(payment)
      [ charge["receipt_email"], (charge["billing_details"] || {})["email"] ]
        .compact.map { |email| email.to_s.downcase.strip }.reject(&:blank?).uniq
    end
    digits = ->(value) { value.to_s.scan(/\d+/).join }
    check_number = lambda do |data|
      text = [ data["PaymentDetails"], data["Note"], data["Description"] ].compact.join(" ")
      text[/(?:check|cjeck)\s*[#(\s]*(\d[\d-]{3,})/i, 1]
    end
    amount_cents = ->(data) { (data["Amount"].to_s.to_d * 100).round }

    portal_rows = Payment.all.map do |payment|
      {
        payment: payment,
        ids: charge_ids.call(payment),
        date: charge_date.call(payment),
        person_id: payment.person_id,
        amount: payment.amount_cents,
        check: digits.call(payment.check_number),
        emails: charge_emails.call(payment),
        consumed: false
      }
    end
    portal_by_id = Hash.new { |hash, key| hash[key] = [] }
    portal_rows.each { |row| row[:ids].each { |id| portal_by_id[id] << row } }

    rows = fm_rows.map do |fm_payment|
      data = fm_payment.data || {}
      people = data["RolodexID"].present? ? Person.with_filemaker_code(data["RolodexID"]).to_a : []
      emails = people.flat_map { |person| [ person.email, person.email_2 ] }
        .compact.map { |email| email.to_s.downcase.strip }.reject(&:blank?).uniq
      {
        fm: fm_payment,
        data: data,
        date: Time.zone.parse(data["DateReceived"].to_s)&.to_date,
        amount: amount_cents.call(data),
        check: check_number.call(data),
        people: people,
        person_ids: people.map(&:id),
        emails: emails,
        matched: false
      }
    end

    # Event labels for search (RefIDs are all events in this archive).
    ref_labels = FmEvent.where(fm_id: rows.map { |row| row[:data]["RefID"] }.compact_blank.uniq)
      .to_a.index_by(&:fm_id).transform_values { |event| event.data["Title"] }

    # The FM details kept for searching the payment index.
    filemaker_metadata = lambda do |row_set|
      data = row_set.map { |row| row[:data] }
      values = lambda do |key|
        data.map { |entry| entry[key] }.compact_blank.uniq
      end
      intents = data.map { |entry| entry["PaymentDetails"].to_s[/Trans ID:\s*(\S+)/i, 1] }.compact_blank.uniq
      labels = data.map { |entry| ref_labels[entry["RefID"]] }.compact_blank.uniq
      {
        "ref_label" => labels.join(" / ").presence,
        "account" => values.call("Account").join(" / ").presence,
        "type" => values.call("Type").join(" / ").presence,
        "payment_method" => values.call("PaymentMethod").join(" / ").presence,
        "stripe_payment_intent" => intents.first
      }.compact
    end

    # 1. Transaction id in PaymentDetails.
    rows.each do |row|
      token = row[:data]["PaymentDetails"].to_s[/Trans ID:\s*(\S+)/i, 1]&.strip
      next if token.blank?

      candidates = portal_by_id[token]
      if candidates.empty?
        body = token.sub(/\A(?:pi|ch|py)_/, "")[0, 19]
        candidates = portal_rows.select do |portal|
          portal[:ids].any? { |id| id.sub(/\A(?:pi|ch|py)_/, "")[0, 19] == body }
        end
      end
      candidates = candidates.reject { |portal| portal[:consumed] }
      next if candidates.empty?

      best = candidates.min_by { |portal| (portal[:date] - row[:date]).abs }
      best[:consumed] = true
      row[:matched] = true
      row[:matched_payment] = best[:payment]
    end

    # 2. One check covering several FileMaker rows.
    rows.reject { |row| row[:matched] }.group_by { |row| row[:check] }.select { |key, _| key.present? }.each do |number, group|
      candidates = portal_rows.select { |portal| portal[:check] == digits.call(number) && !portal[:consumed] }
      next if candidates.empty?

      total = group.sum { |row| row[:amount] }
      best = candidates.min_by { |portal| [ portal[:amount] == total ? 0 : 1, (portal[:date] - group.first[:date]).abs ] }
      group.each do |row|
        row[:matched] = true
        row[:matched_payment] = best[:payment]
      end
      best[:consumed] = true
    end

    # 3. Payer email plus amount.
    rows.reject { |row| row[:matched] }.each do |row|
      next if row[:emails].empty?

      candidates = portal_rows.select do |portal|
        !portal[:consumed] && portal[:amount] == row[:amount] && (portal[:emails] & row[:emails]).any?
      end
      next if candidates.empty?

      best = candidates.min_by { |portal| (portal[:date] - row[:date]).abs }
      best[:consumed] = true
      row[:matched] = true
      row[:matched_payment] = best[:payment]
    end

    # 4. Payer plus amount.
    rows.reject { |row| row[:matched] }.each do |row|
      candidates = portal_rows.select do |portal|
        !portal[:consumed] && portal[:amount] == row[:amount] && row[:person_ids].include?(portal[:person_id])
      end
      next if candidates.empty?

      best = candidates.min_by { |portal| (portal[:date] - row[:date]).abs }
      best[:consumed] = true
      row[:matched] = true
      row[:matched_payment] = best[:payment]
    end

    # 5. Verified by hand.
    verified_payments = Payment.where(id: verified_matches.values.uniq).index_by(&:id)
    rows.each do |row|
      payment_id = verified_matches[row[:fm].fm_id]
      next unless payment_id

      row[:matched] = true
      row[:matched_payment] = verified_payments[payment_id]
    end

    needs_record = rows.reject { |row| row[:matched] || skip_fm_ids.include?(row[:fm].fm_id) || row[:amount] <= 0 }
    by_fm_id = needs_record.index_by { |row| row[:fm].fm_id }

    plans = []
    grouped_payments.each do |group|
      group_rows = group[:ids].filter_map { |id| by_fm_id[id] }
      next if group_rows.empty?

      plans << {
        codes: group[:ids].flat_map { |id| codes_for.call(id) }.uniq.sort,
        amount_cents: group[:amount_cents],
        date: group_rows.map { |row| row[:date] }.compact.min,
        rows: group_rows
      }
    end

    handled_ids = grouped_payments.flat_map { |group| group[:ids] }
    needs_record.reject { |row| handled_ids.include?(row[:fm].fm_id) }.each do |row|
      plans << {
        codes: codes_for.call(row[:fm].fm_id),
        amount_cents: row[:amount],
        date: row[:date],
        rows: [ row ]
      }
    end

    plans = plans.flat_map do |plan|
      if plan[:codes] == [ installment_fm_id ]
        installments.map do |date, cents, number|
          plan.merge(amount_cents: cents, date: date, installment: number)
        end
      else
        [ plan ]
      end
    end

    external_payer = Person.find_by("first_name = ? AND last_name = ?", "External", "Payer")
    existing_codes = FilemakerPayment.pluck(:filemaker_code)
      .flat_map { |value| FilemakerPayment.split_filemaker_codes(value) }.to_set
    existing_installments = FilemakerPayment.all.select do |payment|
      payment.metadata&.dig("filemaker_import", "fm_id") == installment_fm_id
    end.map { |payment| payment.metadata.dig("filemaker_import", "installment").to_i }

    created = []
    skipped = 0
    linked = 0
    failed = []

    Current.user = import_user
    Current.source = "fm_payments_2026"

    ActiveRecord::Base.transaction do
      plans.each do |plan|
        if plan[:installment]
          if existing_installments.include?(plan[:installment])
            skipped += 1
            next
          end
        elsif plan[:codes].any? { |code| existing_codes.include?(code) }
          skipped += 1
          next
        end

        person = plan[:rows].flat_map { |row| row[:people] }.first || external_payer

        if person.nil?
          failed << "#{plan[:codes].join(', ')}: no payer resolved"
          next
        end

        data = plan[:rows].first[:data]
        import_metadata = { "fm_ids" => plan[:codes], "imported_at" => Time.current.iso8601 }
        if plan[:installment]
          import_metadata["fm_id"] = installment_fm_id
          import_metadata["installment"] = plan[:installment]
        end

        payment = FilemakerPayment.new(
          amount_cents: plan[:amount_cents],
          person: person,
          check_number: plan[:rows].first[:check],
          memo: [ data["Type"], data["Description"] ].compact_blank.join(" — ").truncate(255),
          description: data["Note"],
          filemaker_code: plan[:codes].join(", "),
          created_at: plan[:date],
          created_by: import_user,
          updated_by: import_user,
          metadata: {
            "filemaker_import" => import_metadata,
            "filemaker" => filemaker_metadata.call(plan[:rows])
          }
        )

        if payment.save
          created << payment
        else
          failed << "#{plan[:codes].join(', ')}: #{payment.errors.full_messages.to_sentence}"
        end
      end

      rows.select { |row| row[:matched_payment] }.group_by { |row| row[:matched_payment].id }.each do |payment_id, matched_rows|
        payment = Payment.find(payment_id)
        codes = matched_rows.flat_map { |row| codes_for.call(row[:fm].fm_id) }
        merged_codes = Payment.join_filemaker_codes(payment.filemaker_codes + codes)
        existing_metadata = payment.metadata || {}
        merged_metadata = existing_metadata.merge("filemaker" => filemaker_metadata.call(matched_rows))
        next if merged_codes == payment.filemaker_code && merged_metadata == existing_metadata

        payment.update!(filemaker_code: merged_codes, metadata: merged_metadata, updated_by: import_user)
        linked += 1
      end

      raise ActiveRecord::Rollback if dry_run
    end

    total_cents = created.sum(&:amount_cents)
    already_in_portal = rows.count { |row| row[:matched] }
    duplicates_skipped = rows.count do |row|
      !row[:matched] && (skip_fm_ids.include?(row[:fm].fm_id) || row[:amount] <= 0)
    end

    puts "FM payment rows in 2026: #{rows.size}"
    puts "Already represented in portal: #{already_in_portal}"
    puts "Duplicate/zero rows skipped: #{duplicates_skipped}"
    puts "Payment records planned: #{plans.size}"
    puts "Created: #{created.size} ($#{format('%.2f', total_cents / 100.0)})"
    puts "Skipped (already imported): #{skipped}"
    puts "Existing payments linked: #{linked}"
    puts "Failed: #{failed.size}"
    failed.each { |message| puts "  #{message}" }

    if dry_run
      puts "\nDRY RUN — rolled back, nothing written. Set DRY_RUN=false to execute."
    else
      puts "\nDone."
    end
  end
end
