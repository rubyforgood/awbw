require "rails_helper"

# The bulk reminder page keeps every emailable registrant in the list and uses
# the filters only to decide who stays checked. These specs lock in that
# "filter checks, never hides" behaviour and the turbo-frame auto-refresh.
RSpec.describe "Events::BulkReminders", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, cost_cents: 10_000) }
  let!(:jane) { create(:event_registration, event: event, registrant: create(:person, first_name: "Jane", last_name: "Adams")) }
  let!(:sam) { create(:event_registration, event: event, registrant: create(:person, first_name: "Sam", last_name: "Cole")) }

  before { sign_in admin }

  def checked?(body, registration)
    node = Nokogiri::HTML(body).at_css("#registration_ids_#{registration.id}")
    node.present? && node["checked"].present?
  end

  it "checks every registrant by default" do
    get preview_reminder_event_path(event)

    expect(response).to have_http_status(:ok)
    expect(checked?(response.body, jane)).to be(true)
    expect(checked?(response.body, sam)).to be(true)
  end

  it "renders the shared filter bar with the More filters toggle" do
    get preview_reminder_event_path(event)

    expect(response.body).to include(">Filters<")
    expect(response.body).to include("More filters")
    # Name/email are the primary row; a name filter shouldn't force the section open.
    get preview_reminder_event_path(event, name: "jane")
    expect(response.body).to include('id="more-filters-toggle" class="sr-only">')
  end

  it "keeps all registrants visible but only checks the matches when filtered" do
    get preview_reminder_event_path(event, name: "jane"),
        headers: { "Turbo-Frame" => "reminder_recipients" }

    expect(response).to have_http_status(:ok)
    # Both rows still render...
    expect(response.body).to include("Jane Adams")
    expect(response.body).to include("Sam Cole")
    # ...but only the matching registrant stays checked.
    expect(checked?(response.body, jane)).to be(true)
    expect(checked?(response.body, sam)).to be(false)
  end

  it "filters recipients by the shared city search" do
    create(:address, addressable: jane.registrant, city: "Santa Monica")

    get preview_reminder_event_path(event, city: "santa"),
        headers: { "Turbo-Frame" => "reminder_recipients" }

    expect(checked?(response.body, jane)).to be(true)
    expect(checked?(response.body, sam)).to be(false)
  end

  describe "confirm interstitial" do
    it "lists the selected recipients and the message preview without sending yet" do
      expect {
        post confirm_reminder_event_path(event), params: { registration_ids: [ jane.id ], custom_message: "See you soon!" }
      }.not_to change(Notification, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jane Adams")
      expect(response.body).not_to include("Sam Cole")
      # Subject line and the composed message are shown on the interstitial.
      expect(response.body).to include("Reminder: #{event.title}")
      expect(response.body).to include("See you soon!")
      # The selection + composed content carry forward as hidden fields.
      expect(response.body).to include("value=\"#{jane.id}\"")
    end

    # hide_event_card rides along explicitly rather than being omitted when false,
    # so the bounce-back can't be re-defaulted by the event's on-demand flag.
    it "redirects back to the picker when nothing is selected" do
      post confirm_reminder_event_path(event), params: { registration_ids: [] }

      expect(response).to redirect_to(preview_reminder_event_path(event, custom_message: "", custom_subject: "", hide_event_card: "0"))
      expect(flash[:alert]).to be_present
    end

    # #166534 is the grey card's green event-title colour — present only inside the box.
    it "hides the event-details box in the preview when the box is checked" do
      post confirm_reminder_event_path(event), params: { registration_ids: [ jane.id ], hide_event_card: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("#166534")
    end

    it "shows the event-details box in the preview by default" do
      post confirm_reminder_event_path(event), params: { registration_ids: [ jane.id ] }

      expect(response.body).to include("#166534")
    end
  end

  describe "editing a registration from the picker" do
    # Opens in a new tab so the in-progress subject/message draft on the picker
    # isn't lost; the picker page stays put while the registration is edited.
    it "opens each registration edit in a new tab" do
      get preview_reminder_event_path(event),
          headers: { "Turbo-Frame" => "reminder_recipients" }

      link = Nokogiri::HTML(response.body)
        .at_css("a[href*='#{edit_event_registration_path(jane)}']")
      expect(link).to be_present
      expect(link["target"]).to eq("_blank")
      expect(link["href"]).to include("return_to=preview_reminder")
    end

    it "returns to the picker after save" do
      patch event_registration_path(jane),
            params: { return_to: "preview_reminder", event_registration: { intends_to_pay: "1" } }

      expect(response).to redirect_to(preview_reminder_event_path(event))
    end
  end

  describe "sending" do
    it "creates one reminder notification per selected registrant and one admin FYI" do
      expect {
        post send_reminder_event_path(event), params: { registration_ids: [ jane.id, sam.id ], custom_message: "See you soon!" }
      }.to change { Notification.where(kind: "event_registration_reminder").count }.by(2)
        .and have_enqueued_mail(EventMailer, :event_registration_reminder_fyi).once

      expect(response).to redirect_to(registrants_event_path(event))
    end

    it "attributes each reminder to the admin who sent it, not the portal" do
      post send_reminder_event_path(event), params: { registration_ids: [ jane.id, sam.id ] }

      reminders = Notification.where(kind: "event_registration_reminder")
      expect(reminders.count).to eq(2)
      expect(reminders.map(&:sender)).to all(eq(admin))
      # Guards the "FROM: AWBW Portal" regression — a sent-by-hand reminder must
      # carry a sender so the index/show page name the admin.
      expect(reminders.map(&:sender_id)).not_to include(nil)
    end

    it "flags each reminder as bulk so the index marks it with a Bulk pill" do
      post send_reminder_event_path(event), params: { registration_ids: [ jane.id, sam.id ] }

      reminders = Notification.where(kind: "event_registration_reminder")
      expect(reminders.count).to eq(2)
      expect(reminders).to all(be_bulk)
    end

    it "records the hide-event-card choice on each reminder when checked" do
      post send_reminder_event_path(event), params: { registration_ids: [ jane.id, sam.id ], hide_event_card: "1" }

      reminders = Notification.where(kind: "event_registration_reminder")
      expect(reminders.count).to eq(2)
      expect(reminders.map(&:hide_event_card)).to all(be(true))
    end

    it "defaults hide_event_card to false when the box is left unchecked" do
      post send_reminder_event_path(event), params: { registration_ids: [ jane.id ] }

      expect(Notification.where(kind: "event_registration_reminder").map(&:hide_event_card)).to all(be(false))
    end

    # End-to-end: checking the box on the page must carry through the async delivery
    # job into the email that actually lands in the registrant's inbox.
    it "hides the box in the delivered email when the box is checked" do
      perform_enqueued_jobs do
        post send_reminder_event_path(event), params: { registration_ids: [ jane.id ], hide_event_card: "1" }
      end

      reminder = ActionMailer::Base.deliveries.find { |m| m.to == [ jane.registrant.preferred_email ] }
      expect(reminder).to be_present
      # #166534 is the grey card's green event-title colour — gone once the box is hidden.
      expect(reminder.html_part.body.encoded).not_to include("#166534")
    end

    it "keeps the box in the delivered email when the box is left unchecked" do
      perform_enqueued_jobs do
        post send_reminder_event_path(event), params: { registration_ids: [ jane.id ] }
      end

      reminder = ActionMailer::Base.deliveries.find { |m| m.to == [ jane.registrant.preferred_email ] }
      expect(reminder.html_part.body.encoded).to include("#166534")
    end
  end

  describe "the compose page" do
    it "offers a checkbox to hide the event details box" do
      get preview_reminder_event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("hide_event_card")
      expect(response.body).to include("Hide the event details")
    end

    it "reflects a carried-over hidden choice: checkbox ticked and the card pre-hidden in the live preview" do
      get preview_reminder_event_path(event, hide_event_card: "1")

      expect(response).to have_http_status(:ok)
      html = Nokogiri::HTML(response.body)
      expect(html.at_css("#hide_event_card")["checked"]).to be_present
      # In preview the card stays in the DOM but rendered hidden, so the Stimulus
      # toggle can reveal it live without a round-trip.
      card = html.at_css("#reminder-event-card")
      expect(card).to be_present
      expect(card["style"]).to include("display: none")
    end

    it "says on the confirm page when the details box is hidden" do
      post confirm_reminder_event_path(event), params: { registration_ids: [ jane.id ], hide_event_card: "1" }

      expect(response.body).to include("Event details box hidden")
    end

    it "says nothing about the box on the confirm page when it is shown" do
      post confirm_reminder_event_path(event), params: { registration_ids: [ jane.id ] }

      expect(response.body).not_to include("Event details box hidden")
    end

    # Gated on the event carrying a deadline, not on it being on-demand.
    it "puts the completion deadline in the pre-filled message for a live event" do
      event.update!(completion_deadline: Date.new(2026, 8, 30))

      get preview_reminder_event_path(event)

      message = Nokogiri::HTML(response.body).at_css("#custom_message").text
      expect(message).to include("Please complete it by <strong>August 30, 2026</strong>.")
    end

    it "leaves the deadline out of the pre-filled message when the event has none" do
      get preview_reminder_event_path(event)

      message = Nokogiri::HTML(response.body).at_css("#custom_message").text
      expect(message).not_to include("Please complete it by")
    end
  end

  # Self-paced training has no session date, time, or "see you there" — the grey
  # box is wrong for it on every send, so the page defaults to hiding it.
  describe "the compose page for an on-demand event" do
    let(:event) { create(:event, title: "Self-Paced Training", on_demand: true, cost_cents: 10_000) }

    it "pre-checks the hide box and pre-hides the card in the live preview" do
      get preview_reminder_event_path(event)

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("#hide_event_card")["checked"]).to be_present
      expect(html.at_css("#reminder-event-card")["style"]).to include("display: none")
    end

    it "respects an explicit choice to show the box" do
      get preview_reminder_event_path(event, hide_event_card: "0")

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("#hide_event_card")["checked"]).to be_nil
      expect(html.at_css("#reminder-event-card")["style"].to_s).not_to include("display: none")
    end

    # Without the box, nothing else in the body names the event, so the pre-filled
    # message has to carry the title.
    it "names the event in the pre-filled message" do
      get preview_reminder_event_path(event)

      message = Nokogiri::HTML(response.body).at_css("#custom_message").text
      expect(message).to include("training <strong>Self-Paced Training</strong>")
    end

    it "puts the completion deadline in the pre-filled message when the event has one" do
      event.update!(completion_deadline: Date.new(2026, 8, 30))

      get preview_reminder_event_path(event)

      message = Nokogiri::HTML(response.body).at_css("#custom_message").text
      expect(message).to include("Please complete it by <strong>August 30, 2026</strong>.")
    end

    it "leaves the date out of the pre-filled subject" do
      get preview_reminder_event_path(event)

      subject_value = Nokogiri::HTML(response.body).at_css("#custom_subject")["value"]
      expect(subject_value).to eq("AWBW Portal: Reminder: Self-Paced Training")
    end

    # The bounce-back carries the choice as an explicit 0, otherwise the on-demand
    # default would silently re-check the box the admin just cleared.
    it "keeps the box unchecked through an empty-recipient bounce-back" do
      post confirm_reminder_event_path(event), params: { registration_ids: [], hide_event_card: "0" }

      expect(response.headers["Location"]).to include("hide_event_card=0")
      follow_redirect!
      expect(Nokogiri::HTML(response.body).at_css("#hide_event_card")["checked"]).to be_nil
    end
  end
end
