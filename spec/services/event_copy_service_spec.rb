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

    it "keeps the source's survey form even when an older form has the same role" do
      create(:form, role: "day_1_survey")
      newer = create(:form, role: "day_1_survey")
      create(:registration_ticket_callout, event: event, form: newer, builtin_key: "feedback_surveys")

      copy = described_class.copy(event, start_on: new_start_on)

      expect(copy.registration_ticket_callouts.find_by(builtin_key: "feedback_surveys").forms).to eq([ newer ])
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
      FormTransferService.decode(payload(event))
    end

    def payload(event)
      described_class.console_script(event)[/import\("([^"]+)"\)/, 1]
    end

    it "prints a one-line console script that rebuilds the event" do
      script = described_class.console_script(event)

      expect(script).to start_with("EventCopyService.import(\"")
      expect(script.lines.size).to eq(1)
      expect { expect { eval(script) }.to output(/Created event/).to_stdout }.to change(Event, :count).by(1) # rubocop:disable Security/Eval
    end

    it "names the event and its callouts for the source environment" do
      create(:registration_ticket_callout, event: event, title: "Bring supplies")

      copy = described_class.new(other_environment_blueprint(event), match_by: :natural).call(start_on: new_start_on, title: "Winter training")

      expect(copy.title).to eq("FROM TEST: Winter training")
      expect(copy.registration_ticket_callouts.custom.map(&:title)).to eq([ "FROM TEST: Bring supplies" ])
    end

    it "makes a separate copy of the event and its forms for a later version" do
      form = create(:form, name: "Registration", role: "registration")
      event.event_forms.create!(form: form, role: "registration")
      create(:registration_ticket_callout, event: event, title: "Bring supplies")
      blueprint = other_environment_blueprint(event)

      first = described_class.new(blueprint, match_by: :natural).call(start_on: new_start_on)
      second = described_class.new(blueprint, match_by: :natural, version: 2).call(start_on: new_start_on)

      expect(second.title).to eq("FROM TEST V2: Spring training")
      expect(second.registration_ticket_callouts.custom.map(&:title)).to eq([ "FROM TEST V2: Bring supplies" ])
      expect(second.registration_form).to have_attributes(name: "FROM TEST V2: Registration")
      expect(second.registration_form).not_to eq(first.registration_form)
    end

    it "matches staff by email, links a copy of each form, and reports what it can't find" do
      form = create(:form, name: "Registration", role: "registration")
      event.event_forms.create!(form: form, role: "registration")
      matched = create(:event_staff, event: event, person: create(:person, email: "lead@example.com"))
      missing = create(:event_staff, event: event, person: create(:person, first_name: "Gone", last_name: "Away", email: "gone@example.com"))
      blueprint = other_environment_blueprint(event)
      missing.person.update!(email: "moved@example.com", first_name: "Moved")

      service = described_class.new(blueprint, match_by: :natural)
      copy = service.call(start_on: new_start_on)

      expect(copy.registration_form).to have_attributes(name: "FROM TEST: Registration", role: "registration")
      expect(copy.registration_form).not_to eq(form)
      expect(copy.staff_members).to contain_exactly(matched.person)
      expect(service.warnings).to include("Staff Gone Away not found — skipped")
      expect(copy.start_date).to eq(zone.parse("2027-01-11 09:00"))
    end

    it "builds a form copy once however many places link to it" do
      form = create(:form, name: "Registration", role: "registration")
      event.event_forms.create!(form: form, role: "registration")
      create(:registration_ticket_callout, event: event, form: form)

      copy = described_class.new(other_environment_blueprint(event), match_by: :natural).call(start_on: new_start_on)

      expect(copy.registration_ticket_callouts.custom.flat_map(&:forms)).to eq([ copy.registration_form ])
      expect(Form.where(name: "FROM TEST: Registration").count).to eq(1)
    end

    it "reuses the form copy from an earlier import" do
      form = create(:form, name: "CE evaluation", role: "general", anonymous: true)
      create(:registration_ticket_callout, event: event, form: form)
      blueprint = other_environment_blueprint(event)

      first = described_class.new(blueprint, match_by: :natural).call(start_on: new_start_on)
      second = described_class.new(blueprint, match_by: :natural).call(start_on: new_start_on)

      forms = [ first, second ].map { |copy| copy.registration_ticket_callouts.custom.flat_map(&:forms).sole }
      expect(forms.uniq.sole).to have_attributes(name: "FROM TEST: CE evaluation", anonymous: true)
    end

    it "warns when linking a published form copy takes its public link offline" do
      form = create(:form, name: "Registration", role: "registration")
      event.event_forms.create!(form: form, role: "registration")
      live = create(:form, name: "FROM TEST: Registration", role: "registration", slug: "registration-copy", published: true)

      service = described_class.new(other_environment_blueprint(event), match_by: :natural)
      copy = service.call(start_on: new_start_on)

      expect(copy.registration_form).to eq(live)
      expect(live.reload).not_to be_published
      expect(service.warnings).to include(/Form "FROM TEST: Registration" was published/)
    end

    it "builds a copy of a survey form, leaving the target's default survey alone" do
      survey = create(:form, name: "Day 1 evaluation", role: "day_1_survey")
      create(:registration_ticket_callout, event: event, form: survey)

      copy = described_class.new(other_environment_blueprint(event), match_by: :natural).call(start_on: new_start_on)

      expect(copy.registration_ticket_callouts.custom.flat_map(&:forms).sole).to have_attributes(name: "FROM TEST: Day 1 evaluation", role: "day_1_survey")
      expect(Form.survey("day_1_survey")).to eq(survey)
    end

    describe ".compare" do
      it "reports each linked form's copy without changing anything" do
        form = create(:form, name: "Registration", role: "registration")
        create(:form_field, form: form, name: "Are you a facilitator?", position: 1)
        event.event_forms.create!(form: form, role: "registration")
        script = payload(event)

        expect { described_class.compare(script) }.to output("+ \"FROM TEST: Registration\" isn't here — import builds it\n").to_stdout
        expect { expect { described_class.compare(script) }.to output.to_stdout }.not_to change(Form, :count)
        copy = described_class.new(FormTransferService.decode(script), match_by: :natural).call(start_on: new_start_on).registration_form
        expect { described_class.compare(script) }.to output("= Form ##{copy.id} \"FROM TEST: Registration\" matches\n").to_stdout
      end
    end
  end
end
