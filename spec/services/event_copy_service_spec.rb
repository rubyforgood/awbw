require "rails_helper"

RSpec.describe EventCopyService do
  let(:zone) { ActiveSupport::TimeZone[Event::PROGRAM_ZONE] }
  let(:location) { create(:location, city: "Los Angeles", state: "CA", country: "USA") }
  let(:event) do
    create(:event, :published, :featured,
      title: "Spring training",
      abbreviation: "ST26",
      location: location,
      cost_cents: 25_000,
      ce_hours_offered: 12.5,
      template: "editorial",
      rhino_description: "<p>Join us</p>",
      start_date: zone.parse("2026-03-09 09:00"),
      end_date: zone.parse("2026-03-10 17:00"),
      registration_close_date: zone.parse("2026-03-02 23:59"),
      ce_hours_request_deadline: Date.new(2026, 2, 23),
      completion_deadline: Date.new(2026, 4, 9))
  end
  let(:new_start_on) { Date.new(2027, 1, 11) }

  describe ".copy" do
    it "creates an unpublished draft with the source's settings and the given title" do
      copy = described_class.copy(event, start_on: new_start_on, title: "Winter training")

      expect(copy).to be_persisted
      expect(copy).to have_attributes(
        title: "Winter training", cost_cents: 25_000, ce_hours_offered: 12.5, template: "editorial",
        location: location, published: false, featured: false, abbreviation: nil
      )
      expect(copy.rhino_description.to_plain_text).to eq("Join us")
    end

    it "keeps every date the same number of days from the start, at the same local time" do
      copy = described_class.copy(event, start_on: new_start_on)

      expect(copy.start_date).to eq(zone.parse("2027-01-11 09:00"))
      expect(copy.end_date).to eq(zone.parse("2027-01-12 17:00"))
      expect(copy.registration_close_date).to eq(zone.parse("2027-01-04 23:59"))
      expect(copy.ce_hours_request_deadline).to eq(Date.new(2026, 12, 28))
      expect(copy.completion_deadline).to eq(Date.new(2027, 2, 11))
    end

    it "copies the CE timesheet settings, shifting the close time with the start" do
      event.update!(ce_timesheets_enabled: false, ce_timesheet_opens_offset_minutes: -1_440,
        ce_timesheet_closes_at: zone.parse("2026-03-17 17:00"))

      copy = described_class.copy(event, start_on: new_start_on)

      expect(copy).to have_attributes(ce_timesheets_enabled: false, ce_timesheet_opens_offset_minutes: -1_440)
      expect(copy.ce_timesheet_closes_at).to eq(zone.parse("2027-01-19 17:00"))
    end

    it "copies callouts in order with their linked forms, resources, and shifted drip dates" do
      form = create(:form, name: "Day 1 evaluation")
      resource = create(:resource, title: "Worksheet")
      faq = create(:registration_ticket_callout, :builtin, event: event, hidden: true)
      custom = create(:registration_ticket_callout, event: event, title: "Bring supplies",
        display_from: zone.parse("2026-03-08 08:00"))
      custom.registration_ticket_callout_forms.create!(form: form, display_from: zone.parse("2026-03-09 16:00"))
      custom.registration_ticket_callout_resources.create!(resource: resource, subtitle: "Print me")

      copy = described_class.copy(event, start_on: new_start_on)

      callouts = copy.registration_ticket_callouts.to_a
      expect(callouts.first(2).map(&:title)).to eq([ faq.title, "Bring supplies" ])
      expect(callouts.first).to have_attributes(builtin_key: "faq", hidden: true)
      copied = callouts.second
      expect(copied.display_from).to eq(zone.parse("2027-01-10 08:00"))
      expect(copied.registration_ticket_callout_forms.sole).to have_attributes(form: form, display_from: zone.parse("2027-01-11 16:00"))
      expect(copied.registration_ticket_callout_resources.sole).to have_attributes(resource: resource, subtitle: "Print me")
      expect(callouts.map(&:builtin_key).compact.tally.values).to all(eq(1))
    end

    it "links the same forms, staff, and tags without building new forms" do
      form = create(:form, name: "Registration", role: "registration")
      event.event_forms.create!(form: form, role: "registration")
      staff = create(:event_staff, event: event, title: "Lead facilitator", bio: "Hi")
      category = create(:category)
      sector = create(:sector)
      event.categorizable_items.create!(category: category)
      event.sectorable_items.create!(sector: sector, is_primary: true)

      copy = described_class.copy(event, start_on: new_start_on)

      expect(copy.registration_form).to eq(form)
      expect(copy.event_staffs.sole).to have_attributes(person: staff.person, title: "Lead facilitator", bio: "Hi")
      expect(copy.categories).to contain_exactly(category)
      expect(copy.sectorable_items.sole).to have_attributes(sector: sector, is_primary: true)
    end

    it "gives the copy its own image file" do
      create(:primary_asset, :with_file, owner: event)

      copy = described_class.copy(event, start_on: new_start_on)

      expect(copy.primary_asset.file).to be_attached
      expect(copy.primary_asset.file.blob).not_to eq(event.primary_asset.file.blob)
    end

    it "still copies the event, with a warning, when the source image's file is gone" do
      asset = create(:primary_asset, :with_file, owner: event)
      asset.file.blob.service.delete(asset.file.blob.key)

      service = described_class.for_event(event)
      copy = service.call(start_on: new_start_on)

      expect(copy).to be_persisted
      expect(copy.primary_asset).to be_nil
      expect(service.warnings).to include(/PrimaryAsset image not copied/)
    end

    it "reports a missing record once however many places link to it" do
      resource = create(:resource, title: "Worksheet")
      [ "Bring supplies", "Read first" ].each do |title|
        callout = create(:registration_ticket_callout, event: event, title: title)
        callout.registration_ticket_callout_resources.create!(resource: resource)
      end
      service = described_class.for_event(event)
      resource.destroy!

      service.call(start_on: new_start_on)

      expect(service.warnings).to eq([ "Resource \"Worksheet\" not found — skipped" ])
    end

    it "leaves registrations and the source event alone" do
      create(:event_registration, event: event)

      copy = described_class.copy(event, start_on: new_start_on)

      expect(copy.event_registrations).to be_empty
      expect(event.reload).to have_attributes(published: true, abbreviation: "ST26", event_registrations: be_present)
    end
  end

  describe "cross-environment copy" do
    def other_environment_blueprint(event)
      payload = described_class.console_script(event)[/import\("([^"]+)"\)/, 1]
      JSON.parse(Zlib.gunzip(Base64.strict_decode64(payload)))
    end

    it "prints a one-line console script that rebuilds the event" do
      script = described_class.console_script(event)

      expect(script).to start_with("EventCopyService.import(\"")
      expect(script.lines.size).to eq(1)
      expect { expect { eval(script) }.to output(/Created event/).to_stdout }.to change(Event, :count).by(1) # rubocop:disable Security/Eval
    end

    it "matches forms and staff by name and email, and reports what it can't find" do
      form = create(:form, name: "Registration", role: "registration")
      event.event_forms.create!(form: form, role: "registration")
      matched = create(:event_staff, event: event, person: create(:person, email: "lead@example.com"))
      missing = create(:event_staff, event: event, person: create(:person, first_name: "Gone", last_name: "Away", email: "gone@example.com"))
      blueprint = other_environment_blueprint(event)
      missing.person.update!(email: "moved@example.com", first_name: "Moved")

      service = described_class.new(blueprint, match_by: :natural)
      copy = service.call(start_on: new_start_on)

      expect(copy.registration_form).to eq(form)
      expect(copy.staff_members).to contain_exactly(matched.person)
      expect(service.warnings).to include("Staff Gone Away not found — skipped")
      expect(copy.start_date).to eq(zone.parse("2027-01-11 09:00"))
    end

    it "builds a form the target doesn't have, with its questions, options, and resources, once" do
      form = create(:form, name: "Registration", role: "registration", header: "<p>Welcome</p>")
      parent = create(:form_field, form: form, name: "Are you a facilitator?", position: 1, field_identifier: "facilitator")
      child = create(:form_field, form: form, name: "Since when?", position: 2, parent_id: parent.id)
      parent.form_field_answer_options.create!(option_name: "Yes")
      parent.form_field_answer_options.create!(option_name: "No")
      worksheet = create(:resource, title: "Worksheet")
      child.form_field_resources.create!(resource: worksheet)
      event.event_forms.create!(form: form, role: "registration")
      create(:registration_ticket_callout, event: event, form: form)
      blueprint = other_environment_blueprint(event)
      form.update!(name: "Renamed in this environment")

      service = described_class.new(blueprint, match_by: :natural)
      copy = service.call(start_on: new_start_on)

      built = copy.registration_form
      expect(built).not_to eq(form)
      expect(service.form_changes).to eq(built => { created: true, questions: 2, options: 2 })
      expect(built).to have_attributes(name: "Registration", role: "registration", header: "<p>Welcome</p>", published: false)
      fields = built.form_fields.order(:position)
      expect(fields.map(&:name)).to eq([ "Are you a facilitator?", "Since when?" ])
      expect(fields.first.answer_options.map(&:name)).to eq(%w[Yes No])
      expect(fields.second.parent_id).to eq(fields.first.id)
      expect(fields.second.resources).to contain_exactly(worksheet)
      expect(copy.registration_ticket_callouts.custom.flat_map(&:forms)).to eq([ built ])
    end

    it "keeps a built form anonymous when the source form is" do
      form = create(:form, name: "CE evaluation", role: "general", anonymous: true)
      create(:form_field, form: form, name: "How useful was it?", position: 1)
      create(:registration_ticket_callout, event: event, form: form)
      blueprint = other_environment_blueprint(event)
      form.update!(name: "Renamed in this environment")

      copy = described_class.new(blueprint, match_by: :natural).call(start_on: new_start_on)

      built = copy.registration_ticket_callouts.custom.flat_map(&:forms).sole
      expect(built).not_to eq(form)
      expect(built).to be_anonymous
    end

    it "adds only the missing questions and options to a same-name form, keeping its id and answers" do
      form = create(:form, name: "Registration", role: "registration")
      facilitator = create(:form_field, form: form, name: "Are you a facilitator?", position: 1, field_identifier: "facilitator")
      facilitator.form_field_answer_options.create!(option_name: "Yes")
      facilitator.form_field_answer_options.create!(option_name: "No")
      create(:form_field, form: form, name: "Since when?", position: 2, parent_id: facilitator.id)
      create(:form_field, form: form, name: "Dietary needs", position: 3)
      event.event_forms.create!(form: form, role: "registration")
      blueprint = other_environment_blueprint(event)
      # This environment's copy of the form is older: an earlier wording, one option
      # and one follow-up question short, plus a question the source has since dropped.
      facilitator.update!(name: "Facilitator?")
      facilitator.form_field_answer_options.joins(:answer_option).where(answer_options: { name: "No" }).destroy_all
      form.form_fields.find_by(name: "Since when?").destroy!
      form.form_fields.find_by(name: "Dietary needs").update!(name: "Allergies")
      answer = create(:form_answer, form_field: facilitator)

      service = described_class.new(blueprint, match_by: :natural)
      copy = service.call(start_on: new_start_on)

      expect(copy.registration_form).to eq(form)
      expect(service.form_changes).to eq(form => { created: false, questions: 2, options: 1 })
      fields = form.form_fields.order(:position, :id)
      expect(fields.map(&:name)).to eq([ "Facilitator?", "Since when?", "Allergies", "Dietary needs" ])
      expect(fields.first.answer_options.map(&:name)).to contain_exactly("Yes", "No")
      expect(fields.find_by(name: "Since when?").parent_id).to eq(facilitator.id)
      expect(answer.reload.form_field).to eq(facilitator)
    end

    it "warns when linking a published form to the copy takes its public link offline" do
      source_form = create(:form, name: "Registration", role: "registration")
      event.event_forms.create!(form: source_form, role: "registration")
      blueprint = other_environment_blueprint(event)
      source_form.destroy!
      live = create(:form, name: "Registration", role: "registration", slug: "registration", published: true)

      service = described_class.new(blueprint, match_by: :natural)
      copy = service.call(start_on: new_start_on)

      expect(copy.registration_form).to eq(live)
      expect(live.reload).not_to be_published
      expect(service.warnings).to include(/Form "Registration" was published/)
    end

    it "uses the target's form for a survey role rather than building a second one" do
      survey = create(:form, name: "Day 1 evaluation", role: "day_1_survey")
      create(:registration_ticket_callout, event: event, form: survey)
      blueprint = other_environment_blueprint(event)
      survey.update!(name: "Day 1 evaluation (staging)")

      service = described_class.new(blueprint, match_by: :natural)
      copy = service.call(start_on: new_start_on)

      expect(copy.registration_ticket_callouts.custom.flat_map(&:forms)).to eq([ survey ])
      expect(service.form_changes).to eq(survey => { created: false, questions: 0, options: 0 })
    end
  end
end
