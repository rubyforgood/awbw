require "rails_helper"

RSpec.describe "Person profile dues section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  def dues_year(cost_cents: 2_500, start_date: Date.current, subscription: nil)
    create(:dues_registration,
      dues_subscription: subscription || create(:dues_subscription, person: person),
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
  end

  context "as an admin" do
    before { sign_in admin }

    it "lists the person's dues years with cost and status" do
      dues_year

      get person_path(person)

      expect(response).to be_successful
      expect(response.body).to include("Dues")
      expect(response.body).to include("$25")
      expect(response.body).to include("due")
    end

    it "shows the standard rate when the subscription has no override" do
      dues_year

      get person_path(person)

      expect(response.body).to include("Standard ($25)")
    end

    it "shows a locked rate when the subscription has one" do
      subscription = create(:dues_subscription, person: person, rate_cents: 1_500)
      dues_year(subscription: subscription)

      get person_path(person)

      expect(response.body).to include("Locked at $15")
    end

    # Requests render in the viewer's zone (ApplicationController#set_time_zone_from_user,
    # defaulting to Pacific), so midday avoids the date shifting either side of midnight.
    it "shows when the subscription was cancelled" do
      subscription = create(:dues_subscription, person: person,
        cancelled_at: Time.zone.parse("2026-08-03 12:00"))
      dues_year(subscription: subscription)

      get person_path(person)

      expect(response.body).to include("Cancelled Aug 3, 2026")
    end

    it "lists every year, newest first" do
      subscription = create(:dues_subscription, person: person)
      older = dues_year(cost_cents: 0, start_date: Date.current - 1.year, subscription: subscription)
      newer = dues_year(subscription: subscription)

      get person_path(person)

      body = response.body
      expect(body).to include(newer.decorate.term_range, older.decorate.term_range)
      expect(body.index(newer.decorate.term_range)).to be < body.index(older.decorate.term_range)
    end

    it "says so when the person has no subscription" do
      get person_path(person)

      expect(response.body).to include("No dues subscription yet")
    end
  end

  it "is hidden from the person themselves" do
    dues_year
    sign_in owner_user

    get person_path(person)

    expect(response).to be_successful
    expect(response.body).not_to include("No dues subscription yet")
    expect(response.body).not_to include("Standard ($25)")
  end

  it "is hidden from another signed-in user" do
    dues_year
    sign_in create(:user, :with_person)

    get person_path(person)

    expect(response.body).not_to include("Standard ($25)")
  end
end
