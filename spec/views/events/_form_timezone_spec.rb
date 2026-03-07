require "rails_helper"

RSpec.describe "events/_form timezone handling", type: :view do
  let(:user) { create(:user, time_zone: "Pacific Time (US & Canada)") }
  let(:location) { create(:location) }

  before do
    assign(:locations, [ location ])
    assign(:sectors, [])
    assign(:categories_grouped, [])
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:allowed_to?).and_return(true)
  end

  context "when displaying datetime-local fields with user timezone" do
    let(:event) do
      # Use January dates to avoid DST ambiguity (PST = UTC-8)
      create(:event,
             start_date: Time.utc(2026, 1, 15, 20, 0),
             end_date: Time.utc(2026, 1, 15, 22, 0),
             registration_close_date: Time.utc(2026, 1, 14, 20, 0))
    end

    it "converts times to user's timezone via around_action :set_time_zone_from_user" do
      assign(:event, event.decorate)

      # Simulate the around_action :set_time_zone_from_user in ApplicationController
      Time.use_zone(user.time_zone) do
        render

        # PST is UTC-8, so 20:00 UTC = 12:00 PST
        expect(rendered).to have_selector(
          "input[name='event[start_date]'][value='2026-01-15T12:00']"
        )

        expect(rendered).to have_selector(
          "input[name='event[end_date]'][value='2026-01-15T14:00']"
        )

        expect(rendered).to have_selector(
          "input[name='event[registration_close_date]'][value='2026-01-14T12:00']"
        )
      end
    end
  end

  context "when event has nil registration_close_date" do
    let(:event) do
      create(:event,
             start_date: 2.days.from_now,
             end_date: 3.days.from_now,
             registration_close_date: nil)
    end

    it "handles nil registration_close_date gracefully" do
      assign(:event, event.decorate)

      Time.use_zone(user.time_zone) do
        render

        expect(rendered).to have_selector("input[name='event[start_date]']")
        expect(rendered).to have_selector("input[name='event[end_date]']")
        expect(rendered).to have_selector("input[name='event[registration_close_date]']")

        expect(rendered).to have_selector("input[name='event[registration_close_date]'][value='']")
      end
    end
  end
end
