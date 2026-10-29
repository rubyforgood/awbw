require "rails_helper"

RSpec.describe "Membership badges", type: :request do
  let(:start_date) { Date.current + 1.day }

  def upcoming_membership(person)
    create(:membership, person: person, start_date: start_date,
      end_date: start_date + 1.year - 1.day).tap do |membership|
      create(:membership_invoice, membership: membership, start_date: start_date,
        end_date: start_date + 1.year - 1.day, cost_cents: 10_000)
    end
  end

  it "hides the payment badge for an upcoming membership" do
    membership = upcoming_membership(create(:person))
    sign_in create(:user, :admin)

    get membership_path(membership)

    expect(response.body).not_to include("This membership has not started yet.")
    expect(response.body).to include("Upcoming · $100")
  end

  it "offers Pay now on an upcoming invoice when autopay is off" do
    person = create(:person)
    upcoming_membership(person)
    sign_in create(:user, person: person)

    get person_path(person)

    expect(response.body).to include("Pay now", "Upcoming · $100")
    expect(response.body).not_to include("Scheduled for")
  end
end
