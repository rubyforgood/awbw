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

    it "redirects back to the picker when nothing is selected" do
      post confirm_reminder_event_path(event), params: { registration_ids: [] }

      expect(response).to redirect_to(preview_reminder_event_path(event, custom_message: "", custom_subject: ""))
      expect(flash[:alert]).to be_present
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
  end
end
