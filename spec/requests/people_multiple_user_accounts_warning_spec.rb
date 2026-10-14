require "rails_helper"

RSpec.describe "People multiple-user-accounts warning", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  it "flags a person with more than one user account on show and edit, linking to each" do
    person = create(:person)
    first_login = person.user
    second_login = create(:user, person: person)

    get person_path(person)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Multiple user accounts")
    expect(response.body).to include(user_path(first_login), user_path(second_login))

    get edit_person_path(person)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Multiple user accounts")
    expect(response.body).to include(user_path(first_login), user_path(second_login))
  end

  it "does not flag a person with a single user account" do
    person = create(:person)

    get person_path(person)
    expect(response.body).not_to include("Multiple user accounts")

    get edit_person_path(person)
    expect(response.body).not_to include("Multiple user accounts")
  end

  it "links each extra account to a merge preview into the suggested keeper, returning to the page it came from" do
    person = create(:person)
    stale = person.user.tap { |user| user.update_columns(confirmed_at: nil, updated_at: 1.minute.from_now) }
    keeper = create(:user, person: person)

    get edit_person_path(person)

    expect(response.body).to include("Suggested keeper")
    expect(response.body).to include(CGI.escapeHTML(dedupe_preview_users_path(user_to_delete_id: stale.id, user_to_keep_id: keeper.id, return_to: "person_edit", person_id: person.id)))
  end

  describe "returning from the logins merge" do
    let(:person) { create(:person) }
    let!(:keeper) { person.user }
    let!(:extra) { create(:user, person: person) }

    it "points the preview's back link at the person page it came from" do
      get dedupe_preview_users_path(user_to_delete_id: extra.id, user_to_keep_id: keeper.id, return_to: "person_show", person_id: person.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Back to profile")
      expect(response.body).to include(%(href="#{person_path(person)}"))
    end

    it "lands back on the person page after merging" do
      post dedupe_perform_users_path, params: { user_to_delete_id: extra.id, user_to_keep_id: keeper.id, return_to: "person_edit", person_id: person.id }

      expect(response).to redirect_to(edit_person_path(person))
      expect(User.exists?(extra.id)).to be(false)
    end
  end
end
