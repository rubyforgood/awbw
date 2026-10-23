require "rails_helper"

# A person viewing their own profile gets a banner pointing them to edit it
# (outside production, per PersonPolicy#edit_own_profile?).
RSpec.describe "Own profile banner", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  context "as the person themselves" do
    before { sign_in owner_user }

    it "shows the banner with an Edit my data button in place of the header Edit button" do
      get person_path(person)

      page = Capybara.string(response.body)
      expect(page).to have_css("#own-profile", text: "This is your profile")
      expect(page).to have_link("Edit my data", href: edit_person_path(person))
      expect(page).to have_link(href: edit_person_path(person), count: 1)
    end

    it "lists pending change requests" do
      request = create(:profile_change_request, :primary_email, person: person,
                                                requested_by: owner_user, requested_value: "new@example.com")

      get person_path(person)

      expect(response.body).to include("AWBW staff are reviewing your update", "Primary email: new@example.com", "submitted", "View or edit")
      expect(response.body).to include(edit_profile_change_request_path(request))
    end

    it "pluralizes the heading for more than one request" do
      create(:profile_change_request, :primary_email, person: person, requested_by: owner_user)
      create(:profile_change_request, :other, person: person, requested_by: owner_user)

      get person_path(person)

      expect(response.body).to include("AWBW staff are reviewing your updates")
    end

    it "says the current email keeps working only for a primary email request" do
      create(:profile_change_request, :primary_email, person: person, requested_by: owner_user)

      get person_path(person)
      expect(response.body).to include("Your current email stays active until we confirm the change.")

      person.profile_change_requests.destroy_all
      create(:profile_change_request, :other, person: person, requested_by: owner_user)

      get person_path(person)
      expect(response.body).not_to include("Your current email stays active")
    end

    it "hides the banner in production" do
      allow(Rails.env).to receive(:production?).and_return(true)

      get person_path(person)

      expect(response.body).not_to include("This is your profile")
    end
  end

  it "doesn't show the banner to an admin viewing someone else" do
    sign_in create(:user, :admin)

    get person_path(person)

    expect(response.body).not_to include("This is your profile")
    expect(response.body).to include(edit_person_path(person))
  end
end
