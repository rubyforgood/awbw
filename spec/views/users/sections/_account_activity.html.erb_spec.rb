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
  # user), unbounded by time and audience. "See all user activity" must land on
  # the same full history — so it uses the person-scoped path with all_time and
  # every audience, matching the person edit "History" card. Passing a bare
  # user_id (actor FK) with the past-month + visitors/users defaults silently
  # drops staff users and older events, returning zero for a super_user.
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

    it "falls back to the user filter, still unbounded and across all audiences" do
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
