require "rails_helper"

RSpec.describe "Person profile admin-only details", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before do
    person.update!(
      first_name: "Realfirst",
      legal_first_name: "Legalname",
      pronunciation: "SAY-it",
      date_of_birth: Date.new(1990, 3, 14),
      email_2: "secondary@example.com",
      email_2_type: "work",
      best_time_to_call: "Mornings",
      filemaker_code: "FMK-12345",
      racial_ethnic_identity: "Demographic detail here",
      display_name_preference: "first_name_only"
    )
    person.contact_methods.create!(kind: "whatsapp", value: "555-777-1212", contact_type: "personal")
    create(:professional_license, person: person, number: "LIC-ADMINTEST", kind: "LCSW", issuing_state: "CA")
    create(:address, addressable: person, street_address: "123 Admin St")
    tag = create(:staff_tag, name: "Pipeline VIP")
    create(:staff_tagging, staff_tag: tag, staff_taggable: person)
    create(:comment, commentable: person, body: "Internal note here", created_by: admin)
  end

  # Every edit-only piece surfaced on the profile, and the marker text a non-admin
  # must never see.
  admin_visible = [
    "Admin details",
    "Admin only",
    "Legal first name: Legalname",
    "SAY-it",
    "Mar 14",
    "secondary@example.com",
    "Mornings",
    "555-777-1212",
    "LIC-ADMINTEST",
    "123 Admin St",
    "Pipeline VIP",
    "FMK-12345",
    "Demographic detail here",
    "First name only",
    "Comments &amp; communications",
    "Internal note here"
  ]

  context "when an admin views the profile" do
    before do
      sign_in admin
      get person_path(person)
    end

    admin_visible.each do |marker|
      it "surfaces #{marker.inspect} as admin-only content" do
        expect(response.body).to include(marker)
      end
    end
  end

  context "when the owner (non-admin) views their own profile" do
    before do
      sign_in owner_user
      get person_path(person)
    end

    admin_visible.each do |marker|
      it "hides #{marker.inspect} from the non-admin owner" do
        expect(response.body).not_to include(marker)
      end
    end
  end

  it "renders the comments & communications frame without error for an admin" do
    sign_in admin
    get comments_and_communications_path(person_id: person.id),
        headers: { "Turbo-Frame" => "comments_and_communications_results" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("comments_and_communications_results")
  end
end
