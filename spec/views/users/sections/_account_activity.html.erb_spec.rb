require "rails_helper"

RSpec.describe "users/sections/_account_activity", type: :view do
  def render_partial(user)
    render partial: "users/sections/account_activity",
           locals: {
             user: user,
             account_events: Ahoy::Event.none.paginate(page: 1),
             by_user_options: []
           }
  end

  # The card shows resource-based history (auth + user-record events about this
  # user), with no time limit and every audience included. "See all user
  # activity" must land on that same full history — so it links with
  # time_period=all_time and all three audiences, matching the person edit
  # "History" card. A bare user_id (actor FK) instead inherits the index's
  # past-month + visitors/users defaults, which drop staff and older events —
  # returning zero for a super_user.
  context "when the user has a person" do
    let(:user) { create(:user, :with_person) }

    it "links 'See all user activity' to the person's full history" do
      render_partial(user)

      expect(rendered).to have_link(
        "See all user activity",
        href: admin_activities_events_path(
          person_id: user.person_id,
          time_period: "all_time",
          audience: %w[visitors users staff]
        )
      )
    end
  end

  context "when the user has no person" do
    let(:user) { create(:user, person: nil) }

    it "falls back to the user filter, still with all_time and all audiences" do
      render_partial(user)

      expect(rendered).to have_link(
        "See all user activity",
        href: admin_activities_events_path(
          user_id: user.id,
          time_period: "all_time",
          audience: %w[visitors users staff]
        )
      )
    end
  end
end
