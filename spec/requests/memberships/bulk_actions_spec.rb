require "rails_helper"

RSpec.describe "Memberships bulk actions", type: :request do
  before { sign_in create(:user, :admin) }

  it "returns only the failed records for retry" do
    failing_person = create(:person, :without_user, first_name: "Failing", last_name: "Member")
    failing = create(:membership, person: failing_person,
      start_date: Date.current, end_date: 1.year.from_now.to_date)
    passing_person = create(:person, :without_user, first_name: "Passing", last_name: "Member")
    passing = create(:membership, person: passing_person,
      start_date: Date.current, end_date: 1.year.from_now.to_date)

    allow_any_instance_of(Membership).to receive(:update!).and_wrap_original do |original, *args, **kwargs|
      membership = original.receiver
      if membership.id == failing.id
        membership.errors.add(:base, "could not be updated")
        raise ActiveRecord::RecordInvalid.new(membership)
      end

      original.call(*args, **kwargs)
    end

    post perform_bulk_action_memberships_path("set_fee"), params: {
      membership_ids: [ failing.id, passing.id ],
      cost_dollars: "99.50"
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("1 record could not be updated", "Failing Member: could not be updated")
    expect(response.body).not_to include("Passing Member")

    checked_ids = Nokogiri::HTML(response.body)
      .css("input[type='checkbox'][name='membership_ids[]']")
      .map { |input| input["value"] }
    expect(checked_ids).to eq([ failing.id.to_s ])
  end
end
