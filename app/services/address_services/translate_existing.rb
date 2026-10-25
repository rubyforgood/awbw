module AddressServices
  # Rewrites stored address countries and states, and the country/state answers on form
  # submissions, as the dropdowns store them (ADR-0009), filling a locality only where it's
  # Unknown. Each changed record is one autochange Ahoy event, all in one visit. Idempotent,
  # so it runs before and after an import.
  class TranslateExisting
    Result = Data.define(:addresses, :answers, :changes, :unmatched, :rows)
    # One field one record changed (or would change, on a dry run), and whose record it is.
    Row = Data.define(:record_type, :record_id, :person_id, :organization_id, :form_submission_id, :field, :before, :after)
    ROW_HEADERS = Row.members.freeze

    REASON = "address_translation"
    # Each address answer, and the answer beside it that the translation reads alongside.
    ANSWER_PAIRS = {
      "mailing_country" => "mailing_state", "mailing_state" => "mailing_country",
      "organization_country" => "organization_state", "organization_state" => "organization_country"
    }.freeze

    # `log` receives one line per changed record, for the rake task's preview.
    def initialize(dry_run: false, log: nil, user: nil)
      @dry_run = dry_run
      @log = log
      @user = user
    end

    def call
      @translation = AddressTranslation.new
      @tracker = Ahoy::Tracker.new(user: @user)
      @changes = Hash.new(0)
      @rows = []
      addresses = answers = 0

      ActiveRecord::Base.transaction do
        Address.find_each { |address| addresses += 1 if translate_address(address) }
        address_answers.find_each { |answer| answers += 1 if translate_answer(answer) }
      end

      Result.new(addresses:, answers:, changes: @changes, unmatched: @translation.unmatched, rows: @rows)
    end

    private

    def translate_address(address)
      state = @translation.state(address.state, country: address.country)
      country = @translation.country(address.country, state: address.state)
      updates = {}
      updates[:state] = state if state.present? && state != address.state
      updates[:country] = country if country != address.country
      if address.locality.blank? || address.locality == Address::UNKNOWN_LOCALITY
        locality = @translation.locality(city: address.city, state:, country:, county: address.county)
        updates[:locality] = locality if locality != address.locality
      end
      owner = { person_id: (address.addressable_id if address.addressable_type == "Person"),
                organization_id: (address.addressable_id if address.addressable_type == "Organization") }
      apply(address, updates, owner:, title: address.name, addressable_type: address.addressable_type, addressable_id: address.addressable_id)
    end

    def translate_answer(answer)
      identifier = answer.form_field.field_identifier
      paired = paired_answers.dig(answer.form_submission_id, ANSWER_PAIRS[identifier])
      raw = answer.submitted_answer
      translated = if identifier.end_with?("_country")
        @translation.country(raw, state: paired).to_s
      else
        @translation.state(raw, country: paired).to_s
      end
      return false if translated == raw.to_s || (translated.blank? && identifier.end_with?("_state"))

      owner = { person_id: answer.form_submission&.person_id, form_submission_id: answer.form_submission_id }
      apply(answer, { submitted_answer: translated }, owner:, title: answer.form_field.name,
            form_submission_id: answer.form_submission_id, field_identifier: identifier)
    end

    def apply(record, updates, owner:, title:, **extra)
      return false if updates.empty?

      label = record.class.model_name.human
      updates.each do |field, after|
        @changes["#{label} #{field.to_s.humanize(capitalize: false)}: #{record[field].inspect} → #{after.inspect}"] += 1
        @rows << Row.new(record_type: label, record_id: record.id, person_id: nil, organization_id: nil,
                         form_submission_id: nil, **owner, field:, before: record[field], after:)
      end
      @log&.call("  #{label} ##{record.id}: #{updates.map { |field, after| "#{field} #{record[field].inspect} → #{after.inspect}" }.join(', ')}")
      return true if @dry_run

      changes = updates.to_h { |field, after| [ field, { before: record[field], after: } ] }
      record.update_columns(updates)
      @tracker.track("autochange.#{record.class.model_name.singular}", {
        resource_type: record.class.name, resource_id: record.id, resource_title: title, changes:, reason: REASON, **extra
      })
      true
    end

    def address_answers
      FormAnswer.joins(:form_field).where(form_fields: { field_identifier: ANSWER_PAIRS.keys }).includes(:form_field, :form_submission)
    end

    # { submission_id => { identifier => answer } }, read before any answer is rewritten so
    # each translation sees what the person typed beside it.
    def paired_answers
      @paired_answers ||= address_answers.pluck(:form_submission_id, "form_fields.field_identifier", :submitted_answer)
        .each_with_object(Hash.new { |hash, id| hash[id] = {} }) { |(id, identifier, value), map| map[id][identifier] = value }
    end
  end
end
