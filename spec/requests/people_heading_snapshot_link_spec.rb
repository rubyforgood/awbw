require "rails_helper"

RSpec.describe "Snapshot link beside the person's name", type: :request do
  let(:person) { create(:person) }

  def heading_snapshot_link
    Nokogiri::HTML(response.body).at_css("h1 a[href='#{person_snapshot_path(person)}']")
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "shows it in the profile heading" do
      get person_path(person)

      expect(heading_snapshot_link).to be_present
    end

    it "shows it in the edit page heading" do
      get edit_person_path(person)

      expect(heading_snapshot_link).to be_present
    end
  end

  context "as the person themself" do
    let(:user) { create(:user, :with_person) }
    let(:person) { user.person }

    before { sign_in user }

    it "leaves it off the profile heading" do
      get person_path(person)

      expect(response).to have_http_status(:ok)
      expect(heading_snapshot_link).to be_nil
    end
  end
end
