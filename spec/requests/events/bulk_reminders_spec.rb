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

  describe "sending" do
    it "creates one reminder notification per selected registrant and one admin FYI" do
      expect {
        post send_reminder_event_path(event), params: { registration_ids: [ jane.id, sam.id ], custom_message: "See you soon!" }
      }.to change { Notification.where(kind: "event_registration_reminder").count }.by(2)
        .and have_enqueued_mail(EventMailer, :event_registration_reminder_fyi).once

      expect(response).to redirect_to(registrants_event_path(event))
    end
  end
end
