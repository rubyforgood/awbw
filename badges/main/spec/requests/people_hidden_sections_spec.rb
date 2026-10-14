require "rails_helper"

RSpec.describe "Person profile sections the owner hid", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:other_user) { create(:user) }

  before do
    person.update!(profile_is_searchable: true)
    create(:affiliation, person: person)
  end

  def get_section(section)
    get person_path(person, section: section),
        headers: { "Turbo-Frame" => "person_#{section}_section" }
  end

  PeopleController::SECTION_SHARE_FLAGS.each do |section, flag|
    describe "?section=#{section}" do
      context "when #{flag} is off" do
        before { person.update!(flag => false) }

        it "denies it to other signed-in users" do
          sign_in other_user
          get_section(section)

          expect(response).to redirect_to(root_path)
        end

        it "serves it to the owner" do
          sign_in owner_user
          get_section(section)

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("person_#{section}_section")
        end

        it "serves it to an admin" do
          sign_in admin
          get_section(section)

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("person_#{section}_section")
        end
      end

      context "when #{flag} is on" do
        before { person.update!(flag => true) }

        it "serves it to other signed-in users" do
          sign_in other_user
          get_section(section)

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("person_#{section}_section")
        end
      end
    end
  end
end
