require "rails_helper"

RSpec.describe "People#bio", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET /people/:id/bio" do
    context "as an admin" do
      before { sign_in admin }

      it "returns the sanitized profile bio with an edit link when shown" do
        person = create(:person, bio: "<p>Hello <script>alert(1)</script>world</p>", profile_show_bio: true)
        get bio_person_path(person)
        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["has_bio"]).to be(true)
        expect(json["show_bio"]).to be(true)
        expect(json["bio_html"]).to include("Hello").and include("world")
        expect(json["bio_html"]).not_to include("script")
        expect(json["edit_path"]).to eq(edit_person_path(person))
      end

      it "reports no bio when the person hides their profile bio" do
        person = create(:person, bio: "Hidden bio", profile_show_bio: false)
        get bio_person_path(person)
        json = response.parsed_body
        expect(json["show_bio"]).to be(false)
        expect(json["has_bio"]).to be(false)
        expect(json["bio_html"]).to be_nil
      end
    end

    it "forbids a non-admin" do
      person = create(:person, bio: "Some bio", profile_show_bio: true)
      sign_in create(:user)
      get bio_person_path(person)
      expect(response).to redirect_to(root_path)
    end
  end
end
