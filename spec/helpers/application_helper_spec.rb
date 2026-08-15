require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#credited_author_link" do
    let(:person) { create(:person, first_name: "Ada", last_name: "Lovelace") }

    it "links to the person profile when the credit resolves to a searchable person" do
      allow(person).to receive(:profile_is_searchable).and_return(true)
      workshop = create(:workshop, author_credit_preference: "full_name")
      allow(workshop).to receive(:author).and_return(person)

      html = helper.credited_author_link(workshop)
      expect(html).to include("<a")
      expect(html).to include(person_path(person))
      expect(html).to include("Ada Lovelace")
    end

    it "renders plain text when the person profile is not searchable" do
      allow(person).to receive(:profile_is_searchable).and_return(false)
      workshop = create(:workshop, author_credit_preference: "full_name")
      allow(workshop).to receive(:author).and_return(person)

      expect(helper.credited_author_link(workshop)).to eq("Ada Lovelace")
    end

    it "never links an anonymous credit, even to a searchable person" do
      allow(person).to receive(:profile_is_searchable).and_return(true)
      workshop = create(:workshop, author_credit_preference: "anonymous")
      allow(workshop).to receive(:author).and_return(person)

      expect(helper.credited_author_link(workshop)).to eq("Anonymous")
    end

    it "renders a legacy free-text author as plain text with no link" do
      workshop = create(:workshop, author: nil, full_name: "Jane Legacy",
                                   created_by: create(:user, person: nil))

      expect(helper.credited_author_link(workshop)).to eq("Jane Legacy")
    end

    it "shows a creator-fallback credit as plain text, never linking the creator's profile" do
      creator_person = create(:person, first_name: "Cara", last_name: "Creator")
      allow(creator_person).to receive(:profile_is_searchable).and_return(true)
      creator = create(:user)
      allow(creator).to receive(:person).and_return(creator_person)
      workshop = create(:workshop, author: nil, full_name: nil, author_credit_preference: "full_name")
      allow(workshop).to receive(:author).and_return(nil)
      allow(workshop).to receive(:created_by).and_return(creator)

      result = helper.credited_author_link(workshop)
      expect(result).to eq("Cara Creator")
      expect(result).not_to include("<a")
    end
  end

  describe "#timezone_visibility_hint" do
    let(:me) { create(:user) }
    let(:other) { create(:user) }

    before { allow(helper).to receive(:current_user).and_return(me) }

    it "uses second person when the form is about the current user" do
      expect(helper.timezone_visibility_hint(me)).to eq("You will see times and dates in this timezone.")
    end

    it "uses 'User' when an admin edits someone else" do
      expect(helper.timezone_visibility_hint(other)).to eq("User will see times and dates in this timezone.")
    end
  end

  describe "#dollars_from_cents" do
    it "drops the cents for whole-dollar amounts and adds thousands separators" do
      expect(helper.dollars_from_cents(150_000)).to eq("$1,500")
      expect(helper.dollars_from_cents(5_000)).to eq("$50")
      expect(helper.dollars_from_cents(1_234_500)).to eq("$12,345")
      expect(helper.dollars_from_cents(0)).to eq("$0")
    end

    it "keeps the cents for fractional amounts" do
      expect(helper.dollars_from_cents(75_050)).to eq("$750.50")
      expect(helper.dollars_from_cents(1_099)).to eq("$10.99")
      expect(helper.dollars_from_cents(1_234_556)).to eq("$12,345.56")
    end
  end

  describe "#staging_environment?" do
    context "when RAILS_ENV is staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("staging")
      end

      it "returns true" do
        expect(helper.staging_environment?).to be true
      end
    end

    context "when Rails.env is staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return(nil)
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("staging"))
      end

      it "returns true" do
        expect(helper.staging_environment?).to be true
      end
    end

    context "when environment is not staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("production")
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      end

      it "returns false" do
        expect(helper.staging_environment?).to be false
      end
    end
  end

  describe "#navbar_bg_class" do
    context "when in staging environment" do
      before do
        allow(helper).to receive(:staging_environment?).and_return(true)
      end

      it "returns bg-red-600" do
        expect(helper.navbar_bg_class).to eq("bg-red-600")
      end
    end

    context "when not in staging environment" do
      before do
        allow(helper).to receive(:staging_environment?).and_return(false)
      end

      it "returns bg-primary" do
        expect(helper.navbar_bg_class).to eq("bg-primary")
      end
    end
  end

  describe "#favicon_file" do
    context "when environment is production" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      end

      it "returns logo-circle.png" do
        expect(helper.favicon_file).to eq("logo-circle.png")
      end
    end

    context "when environment is staging" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("staging"))
      end

      it "returns favicon.png" do
        expect(helper.favicon_file).to eq("favicon.png")
      end
    end

    context "when environment is development" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      end

      it "returns theme_default.png" do
        expect(helper.favicon_file).to eq("theme_default.png")
      end
    end

    context "when environment is test" do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("test"))
      end

      it "returns theme_default.png" do
        expect(helper.favicon_file).to eq("theme_default.png")
      end
    end
  end

  describe "#form_label_html" do
    it "preserves allowed formatting and link tags" do
      input = %(Visit <a href="https://example.com">our site</a><br>line two <strong>bold</strong>)
      expect(helper.form_label_html(input)).to eq(input)
    end

    it "keeps heading tags" do
      expect(helper.form_label_html("<h2>Section</h2>")).to eq("<h2>Section</h2>")
    end

    it "keeps collapsible <details>/<summary> disclosures (incl. the open state)" do
      input = %(<details open><summary>Workshop 1</summary><ul><li>Glue</li></ul></details>)
      # The sanitizer normalizes the boolean attribute to open="" — functionally identical.
      expect(helper.form_label_html(input)).to eq(%(<details open=""><summary>Workshop 1</summary><ul><li>Glue</li></ul></details>))
    end

    it "keeps font size and color via inline style" do
      input = %(<span style="font-size:24px;color:#ff0000">big red</span>)
      result = helper.form_label_html(input)
      expect(result).to include("font-size:24px")
      expect(result).to include("color:#ff0000")
    end

    it "keeps font size and color via the font tag" do
      input = %(<font size="5" color="blue">styled</font>)
      expect(helper.form_label_html(input)).to eq(input)
    end

    it "scrubs dangerous css from the style attribute while keeping safe properties" do
      result = helper.form_label_html(%(<span style="color:red;background:url(javascript:alert(1))">x</span>))
      expect(result).to include("color:red")
      expect(result).not_to include("javascript")
    end

    it "strips disallowed tags but keeps their text" do
      expect(helper.form_label_html("<script>alert(1)</script>Hello")).to eq("alert(1)Hello")
    end

    it "removes dangerous link schemes" do
      result = helper.form_label_html(%(<a href="javascript:alert(1)">x</a>))
      expect(result).not_to include("javascript:")
    end

    it "returns an html_safe string" do
      expect(helper.form_label_html("<br>")).to be_html_safe
    end
  end

  describe "#form_header_html" do
    it "fills the {{event_month_year}} token from the event's start date" do
      form = build(:form, header: "Register for our {{event_month_year}} training.")
      event = build(:event, start_date: Time.zone.local(2026, 7, 23))
      expect(helper.form_header_html(form, event: event)).to eq("Register for our July 2026 training.")
    end

    it "falls back to a neutral phrase when no event is given" do
      form = build(:form, header: "Register for our {{event_month_year}} training.")
      expect(helper.form_header_html(form)).to eq("Register for our upcoming training.")
    end

    it "fills the {{registration_close}} token as 'Month Day at time' without the year or ordinal" do
      form = build(:form, header: "Registration closes {{registration_close}}.")
      close = Time.zone.local(2026, 7, 20, 9, 0)
      event = build(:event, registration_close_date: close)
      tz = close.strftime("%Z")
      expect(helper.form_header_html(form, event: event))
        .to eq("Registration closes July 20 at 9am #{tz}.")
    end

    it "includes minutes in the {{registration_close}} token when not on the hour" do
      form = build(:form, header: "Registration closes {{registration_close}}.")
      close = Time.zone.local(2026, 7, 20, 14, 30)
      event = build(:event, registration_close_date: close)
      tz = close.strftime("%Z")
      expect(helper.form_header_html(form, event: event))
        .to eq("Registration closes July 20 at 2:30pm #{tz}.")
    end

    it "falls back when the event has no registration close date" do
      form = build(:form, header: "Registration closes {{registration_close}}.")
      event = build(:event, registration_close_date: nil)
      expect(helper.form_header_html(form, event: event)).to eq("Registration closes soon.")
    end

    it "fills the {{event_title}} token" do
      form = build(:form, header: "Welcome to {{event_title}}.")
      event = build(:event, title: "AWBW Facilitator Training")
      expect(helper.form_header_html(form, event: event)).to eq("Welcome to AWBW Facilitator Training.")
    end

    it "fills the {{event_dates}} token, collapsing a same-month multi-day range" do
      form = build(:form, header: "Dates: {{event_dates}}.")
      event = build(:event, start_date: Time.zone.local(2026, 7, 23, 9), end_date: Time.zone.local(2026, 7, 24, 16, 30))
      expect(helper.form_header_html(form, event: event)).to eq("Dates: July 23-24, 2026.")
    end

    it "fills the {{event_times}} token, hiding :00 minutes and showing the range" do
      form = build(:form, header: "Time: {{event_times}}.")
      event = build(:event, start_date: Time.zone.local(2026, 7, 23, 9), end_date: Time.zone.local(2026, 7, 23, 16, 30))
      zone = event.start_date.in_time_zone(Time.zone).strftime("%Z")
      expect(helper.form_header_html(form, event: event)).to eq("Time: 9 am - 4:30 pm #{zone}.")
    end

    it "fills the {{event_fee}} token with a formatted amount, and Free when zero" do
      form = build(:form, header: "Fee: {{event_fee}}.")
      expect(helper.form_header_html(form, event: build(:event, cost_cents: 150_000))).to eq("Fee: $1,500.")
      expect(helper.form_header_html(form, event: build(:event, cost_cents: 0))).to eq("Fee: Free.")
    end

    it "fills the {{event_platform}} token only when a videoconference link is set" do
      form = build(:form, header: "Platform: {{event_platform}}.")
      online = build(:event, videoconference_url: "https://zoom.us/j/1", videoconference_label: "Zoom")
      in_person = build(:event, videoconference_url: nil)
      expect(helper.form_header_html(form, event: online)).to eq("Platform: Zoom.")
      expect(helper.form_header_html(form, event: in_person)).to eq("Platform: online.")
    end

    it "fills the {{event_location}} token from the event's location" do
      form = build(:form, header: "Location: {{event_location}}.")
      event = build(:event, location: build(:location, city: "Los Angeles", state: "CA"))
      expect(helper.form_header_html(form, event: event)).to eq("Location: Los Angeles, CA.")
    end

    it "falls back when the event has no location" do
      form = build(:form, header: "Location: {{event_location}}.")
      expect(helper.form_header_html(form, event: build(:event, location: nil))).to eq("Location: the event location.")
    end

    it "sanitizes the header markup" do
      form = build(:form, header: "<strong>Hi</strong><script>alert(1)</script>")
      expect(helper.form_header_html(form)).to eq("<strong>Hi</strong>alert(1)")
    end
  end

  describe "#form_header_uses_tokens?" do
    it "is true when the header contains a known placeholder" do
      expect(helper.form_header_uses_tokens?(build(:form, header: "Closes {{registration_close}}."))).to be true
    end

    it "is false for plain headers or none" do
      expect(helper.form_header_uses_tokens?(build(:form, header: "Welcome!"))).to be false
      expect(helper.form_header_uses_tokens?(build(:form, header: nil))).to be false
    end
  end

  describe "#event_dates_detail_label" do
    it "shows weekday and date without a year for a single-day event" do
      event = build(:event, start_date: Time.zone.local(2026, 8, 12, 9), end_date: Time.zone.local(2026, 8, 12, 12))
      expect(helper.event_dates_detail_label(event)).to eq("Wednesday, August 12")
    end

    it "shows a weekday range for a same-month multi-day event" do
      event = build(:event, start_date: Time.zone.local(2026, 7, 23, 9), end_date: Time.zone.local(2026, 7, 24, 16))
      expect(helper.event_dates_detail_label(event)).to eq("Thursday-Friday, July 23-24")
    end

    it "spells out both ends for a cross-month multi-day event" do
      event = build(:event, start_date: Time.zone.local(2026, 7, 30, 9), end_date: Time.zone.local(2026, 8, 2, 16))
      expect(helper.event_dates_detail_label(event)).to eq("Thursday, July 30 - Sunday, August 2")
    end

    it "is nil when the event has no start date" do
      expect(helper.event_dates_detail_label(build(:event, start_date: nil))).to be_nil
    end
  end

  describe "#event_platform_label" do
    it "is nil for in-person events with no videoconference link" do
      expect(helper.event_platform_label(build(:event, videoconference_url: nil))).to be_nil
    end

    it "uses the videoconference label when one is set" do
      event = build(:event, videoconference_url: "https://zoom.us/j/1", videoconference_label: "Zoom")
      expect(helper.event_platform_label(event)).to eq("Zoom")
    end

    it "derives the platform from the link when the label is blank" do
      event = build(:event, videoconference_url: "https://us02web.zoom.us/j/1", videoconference_label: "")
      expect(helper.event_platform_label(event)).to eq("Zoom")
    end
  end

  describe "#reminder_days_phrase" do
    it "says today for 0 days" do
      expect(helper.reminder_days_phrase(0)).to eq(" <strong>today</strong>")
    end

    it "says tomorrow for 1 day" do
      expect(helper.reminder_days_phrase(1)).to eq(" <strong>tomorrow</strong>")
    end

    it "bolds the day count for more than one day out" do
      expect(helper.reminder_days_phrase(60)).to eq(" in <strong>60 days</strong>")
    end

    it "is blank when the day count is unknown" do
      expect(helper.reminder_days_phrase(nil)).to eq("")
    end
  end

  describe "#default_reminder_message" do
    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("ORGANIZATION_NAME", "AWBW").and_return("A Window Between Worlds")
    end

    it "names the organization and the bolded dynamic day count" do
      expect(helper.default_reminder_message(60))
        .to eq("This is a reminder that you're registered for the following A Window Between Worlds event in <strong>60 days</strong>.")
    end

    it "omits the day phrase when the count is unknown" do
      expect(helper.default_reminder_message(nil))
        .to eq("This is a reminder that you're registered for the following A Window Between Worlds event.")
    end

    # Self-paced training has no session date, and admins hide the details box for
    # it — so "the following event" would point at nothing. The copy carries the
    # title itself instead, and drops the day count.
    it "names an on-demand event inline instead of pointing at the details box" do
      event = build(:event, title: "Trauma-Informed Basics", on_demand: true)
      expect(helper.default_reminder_message(60, event: event))
        .to eq("This is a reminder that you're registered for the A Window Between Worlds training <strong>Trauma-Informed Basics</strong>.")
    end

    # These titles already carry the format ("On-Demand Training 2026"), so the
    # copy says "training" and lets the title speak for itself.
    it "does not repeat 'on-demand' ahead of a title that already says it" do
      event = build(:event, title: "On-Demand Training 2026", on_demand: true)
      expect(helper.default_reminder_message(nil, event: event))
        .to eq("This is a reminder that you're registered for the A Window Between Worlds training <strong>On-Demand Training 2026</strong>.")
    end

    it "escapes HTML in an on-demand event title" do
      event = build(:event, title: "Art & <Healing>", on_demand: true)
      expect(helper.default_reminder_message(nil, event: event)).to include("Art &amp; &lt;Healing&gt;")
    end

    it "keeps the live-event copy when the event is not on-demand" do
      event = build(:event, title: "Healing Workshop", on_demand: false)
      expect(helper.default_reminder_message(60, event: event))
        .to eq("This is a reminder that you're registered for the following A Window Between Worlds event in <strong>60 days</strong>.")
    end

    # Every event with a deadline carries it in the editable copy, so admins can
    # reword it. There is no standalone block in the email template.
    it "adds the completion deadline to an on-demand event's copy" do
      event = build(:event, title: "On-Demand Training 2026", on_demand: true, completion_deadline: Date.new(2026, 8, 30))
      expect(helper.default_reminder_message(nil, event: event))
        .to eq("This is a reminder that you're registered for the A Window Between Worlds training <strong>On-Demand Training 2026</strong>. Please complete it by <strong>August 30, 2026</strong>.")
    end

    it "leaves the deadline sentence out when an on-demand event has no deadline" do
      event = build(:event, title: "On-Demand Training 2026", on_demand: true, completion_deadline: nil)
      expect(helper.default_reminder_message(nil, event: event)).not_to include("Please complete it by")
    end

    it "adds the completion deadline to a live event's copy too" do
      event = build(:event, title: "Healing Workshop", on_demand: false, completion_deadline: Date.new(2026, 8, 30))
      expect(helper.default_reminder_message(60, event: event))
        .to eq("This is a reminder that you're registered for the following A Window Between Worlds event in <strong>60 days</strong>. Please complete it by <strong>August 30, 2026</strong>.")
    end

    it "leaves the deadline sentence out when a live event has no deadline" do
      event = build(:event, title: "Healing Workshop", on_demand: false, completion_deadline: nil)
      expect(helper.default_reminder_message(60, event: event)).not_to include("Please complete it by")
    end
  end

  describe "#default_reminder_subject" do
    it "uses the AWBW Portal prefix with the event title and formatted start date" do
      event = build(:event, title: "Healing Workshop", start_date: Time.zone.local(2026, 8, 7, 18, 0))
      expect(helper.default_reminder_subject(event))
        .to eq("AWBW Portal: Reminder: Healing Workshop – August 7, 2026")
    end

    it "omits the date suffix when the event has no start date" do
      event = build(:event, title: "Healing Workshop", start_date: nil)
      expect(helper.default_reminder_subject(event))
        .to eq("AWBW Portal: Reminder: Healing Workshop")
    end

    # A start date on self-paced training is an enrollment boundary, not a session
    # time — putting it in the subject reads as "be there on August 7".
    it "omits the date suffix for an on-demand event that has a start date" do
      event = build(:event, title: "Healing Workshop", start_date: Time.zone.local(2026, 8, 7, 18, 0), on_demand: true)
      expect(helper.default_reminder_subject(event))
        .to eq("AWBW Portal: Reminder: Healing Workshop")
    end
  end

  describe "#event_registration_close_date_label" do
    it "is the month and day, without year, ordinal, or time" do
      event = build(:event, registration_close_date: Time.zone.local(2026, 8, 7, 8, 45))
      expect(helper.event_registration_close_date_label(event)).to eq("August 7")
    end

    it "is nil when there's no close date" do
      expect(helper.event_registration_close_date_label(build(:event, registration_close_date: nil))).to be_nil
    end
  end

  describe "#event_registration_close_time_label" do
    it "is the zoned time prefixed with 'at', keeping minutes when not on the hour" do
      close = Time.zone.local(2026, 8, 7, 8, 45)
      event = build(:event, registration_close_date: close)
      expect(helper.event_registration_close_time_label(event)).to eq("at 8:45am #{close.strftime("%Z")}")
    end

    it "hides :00 minutes" do
      close = Time.zone.local(2026, 7, 20, 9, 0)
      event = build(:event, registration_close_date: close)
      expect(helper.event_registration_close_time_label(event)).to eq("at 9am #{close.strftime("%Z")}")
    end

    it "is nil when there's no close date" do
      expect(helper.event_registration_close_time_label(build(:event, registration_close_date: nil))).to be_nil
    end
  end

  describe "#event_registration_close_default" do
    it "is 9am on the Monday of the start date's week" do
      event = build(:event, start_date: Time.zone.local(2026, 7, 22, 13, 0)) # Wednesday
      expect(helper.event_registration_close_default(event)).to eq(Time.zone.local(2026, 7, 20, 9, 0))
    end

    it "is the prior Monday at 9am when the event starts on a Monday" do
      event = build(:event, start_date: Time.zone.local(2026, 7, 20, 9, 0)) # Monday
      expect(helper.event_registration_close_default(event)).to eq(Time.zone.local(2026, 7, 13, 9, 0))
    end

    it "falls back to two days out at 9am when there is no start date" do
      event = build(:event, start_date: nil)
      default = helper.event_registration_close_default(event)
      expect(default.hour).to eq(9)
      expect(default.min).to eq(0)
      expect(default.to_date).to eq(2.days.from_now.to_date)
    end
  end

  describe "#routable_path for a form submission" do
    it "links to the registration details page when the submitter is registered" do
      event = create(:event)
      form = create(:form)
      create(:event_form, event: event, form: form, role: "registration")
      person = create(:person)
      registration = create(:event_registration, event: event, registrant: person)
      submission = create(:form_submission, event: nil, form: form, person: person, role: "registration")

      expect(helper.routable_path(submission))
        .to eq(event_public_registration_path(event, reg: registration.slug))
    end

    it "falls back to the form submission show page without a registration" do
      submission = create(:form_submission)

      expect(helper.routable_path(submission)).to eq(form_submission_path(submission))
    end
  end

  describe "#noticeable_type_label" do
    it "names registrations and bulk payments in plain language" do
      registration = build(:event_registration)
      bulk = build(:form_submission, role: "bulk_payment")
      submission = build(:form_submission, role: "registration")

      expect(helper.noticeable_type_label(registration)).to eq("Registration")
      expect(helper.noticeable_type_label(bulk)).to eq("Bulk payment")
      expect(helper.noticeable_type_label(submission)).to eq("Form submission")
    end

    it "humanizes other model names" do
      expect(helper.noticeable_type_label(build(:user))).to eq("User")
    end
  end

  describe "#noticeable_label" do
    it "describes a registration by registrant and event" do
      person = create(:person, first_name: "Jane", last_name: "Doe")
      event = create(:event, title: "Summer Workshop")
      registration = create(:event_registration, registrant: person, event: event)

      expect(helper.noticeable_label(registration)).to eq("#{person.name} · Summer Workshop")
    end

    it "describes a form submission by submitter and form" do
      person = create(:person, first_name: "Jane", last_name: "Doe")
      form = create(:form, name: "Bulk Payment")
      submission = create(:form_submission, person: person, form: form)

      expect(helper.noticeable_label(submission)).to eq("#{person.name} · Bulk Payment")
    end

    it "uses the record's own name for other models" do
      user = build(:user)

      expect(helper.noticeable_label(user)).to eq(user.name)
    end
  end

  describe "#dynamic_form_field_options" do
    let(:form) { create(:form) }

    it "omits the Other sector for the primary service-area dropdown" do
      create(:sector, :published, name: "Domestic Violence")
      create(:sector, :published, name: "Other")
      field = create(:form_field, form: form, answer_type: :single_select_dropdown, field_identifier: "primary_service_area_single")

      labels = helper.dynamic_form_field_options(field).map(&:first)
      expect(labels).to include("Domestic Violence")
      expect(labels).not_to include("Other")
    end

    it "includes the Other sector for the additional service-areas field" do
      create(:sector, :published, name: "Other")
      field = create(:form_field, form: form, answer_type: :multi_select_checkbox, field_identifier: "primary_service_area")

      labels = helper.dynamic_form_field_options(field).map(&:first)
      expect(labels).to include("Other")
    end

    it "carries each sector's description as the third tuple element" do
      create(:sector, :published, name: "Domestic Violence", description: "DV services")
      create(:sector, :published, name: "Mental Health", description: nil)
      field = create(:form_field, form: form, answer_type: :multi_select_checkbox, field_identifier: "primary_service_area")

      descriptions = helper.dynamic_form_field_options(field).to_h { |name, _id, desc| [ name, desc ] }
      expect(descriptions["Domestic Violence"]).to eq("DV services")
      expect(descriptions["Mental Health"]).to be_nil
    end

    it "offers the published AgeRange categories for the primary age group field" do
      type = create(:category_type, name: "AgeRange")
      create(:category, :published, category_type: type, name: "Children (0-12)")
      create(:category, :unpublished, category_type: type, name: "Retired range")
      field = create(:form_field, form: form, answer_type: :multi_select_checkbox, field_identifier: "primary_age_group")

      labels = helper.dynamic_form_field_options(field).map(&:first)
      expect(labels).to include("Children (0-12)")
      expect(labels).not_to include("Retired range")
    end
  end

  describe "#badge_classes" do
    it "builds the pill recipe with the theme classes and default padding" do
      result = helper.badge_classes("bg-green-50 text-green-700 border-green-200")

      expect(result).to include("inline-flex items-center gap-1.5 whitespace-nowrap rounded-full border text-xs font-medium")
      expect(result).to include("bg-green-50 text-green-700 border-green-200")
      expect(result).to include("px-2 py-0.5")
    end

    it "accepts custom padding" do
      expect(helper.badge_classes("bg-blue-50", padding: "px-5 py-0.5")).to include("px-5 py-0.5")
    end
  end
end
