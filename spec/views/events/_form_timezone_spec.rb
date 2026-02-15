require 'rails_helper'

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
      # Create event with specific UTC times
      create(:event,
             start_date: Time.utc(2026, 3, 15, 20, 0), # 8:00 PM UTC
             end_date: Time.utc(2026, 3, 15, 22, 0),   # 10:00 PM UTC
             registration_close_date: Time.utc(2026, 3, 14, 20, 0)) # Day before, 8:00 PM UTC
    end

    it "converts times to user's timezone (Pacific)" do
      assign(:event, event.decorate)
      
      # Mock Time.zone to return Pacific timezone (like ApplicationController does)
      allow(Time).to receive(:zone).and_return(ActiveSupport::TimeZone["Pacific Time (US & Canada)"])
      
      render
      
      # Pacific Time is UTC-8, so 8 PM UTC = 12 PM Pacific
      # The form should display "2026-03-15T12:00" not "2026-03-15T20:00"
      expect(rendered).to have_selector(
        "input[name='event[start_date]'][value='2026-03-15T12:00']"
      )
      
      expect(rendered).to have_selector(
        "input[name='event[end_date]'][value='2026-03-15T14:00']"
      )
      
      expect(rendered).to have_selector(
        "input[name='event[registration_close_date]'][value='2026-03-14T12:00']"
      )
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
      
      render
      
      # Should render the input field but with empty value
      expect(rendered).to have_selector("input[name='event[registration_close_date]']")
    end
  end
end
