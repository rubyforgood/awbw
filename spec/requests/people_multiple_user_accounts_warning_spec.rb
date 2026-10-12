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
end
