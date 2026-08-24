require "rails_helper"

RSpec.describe "Person blog contributor flag", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  context "as an admin" do
    before { sign_in admin }

    it "renders the blog-contributor toggle on the edit form" do
      get edit_person_path(person)

      expect(response.body).to include("Blog contributor")
    end

    it "persists the blog-contributor flag on update" do
      patch person_path(person), params: { person: { blog_contributor: "1" } }

      expect(person.reload.blog_contributor).to be(true)
    end
  end

  context "as the profile owner (non-admin)" do
    let(:owner_user) { create(:user, :with_person) }
    let(:person) { owner_user.person }

    before { sign_in owner_user }

    it "does not render the admin-only blog-contributor toggle" do
      get edit_person_path(person)

      expect(response.body).not_to include("Blog contributor")
    end
  end
end
