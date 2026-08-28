require "rails_helper"

RSpec.describe "/staff_tags", type: :request do
  let(:admin) { create(:user, :admin, :with_person) }

  describe "as an admin" do
    before { sign_in admin }

    it_behaves_like "a page with a change log" do
      let(:record) { create(:staff_tag) }
      let(:page_path) { staff_tag_path(record) }
    end

    it "lists staff tags" do
      tag = create(:staff_tag, name: "Highlight roster")
      get staff_tags_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Highlight roster")
    end

    it "shows tagged people with who applied the tag, plus audit info" do
      tag = create(:staff_tag, name: "Highlight roster", created_by: admin, updated_by: admin)
      person = create(:person, first_name: "Ada", last_name: "Tagged")
      tag.staff_taggings.create!(staff_taggable: person, created_by: admin)

      get staff_tag_path(tag)

      expect(response.body).to include("Ada Tagged")
      expect(response.body).to include("Tagged")
      expect(response.body).to include(admin.full_name)
      expect(response.body).to include("Created:")
    end

    it "creates a staff tag and stamps the author" do
      expect {
        post staff_tags_path, params: { staff_tag: { name: "Potential future trainer", description: "Pipeline" } }
      }.to change(StaffTag, :count).by(1)

      tag = StaffTag.order(:created_at).last
      expect(tag.name).to eq("Potential future trainer")
      expect(tag.created_by).to eq(admin)
      expect(response).to redirect_to(staff_tag_path(tag))
    end

    it "rejects a blank name" do
      post staff_tags_path, params: { staff_tag: { name: "" } }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renders the staff-tag-specific published hint, not the generic one" do
      get new_staff_tag_path
      expect(response.body).to include("Offered in the tag pickers")
      expect(response.body).not_to include("Visible to signed-in users")
    end

    it "publishes and unpublishes via the edit form" do
      tag = create(:staff_tag)

      patch staff_tag_path(tag), params: { staff_tag: { published: "0" } }
      expect(tag.reload).not_to be_published

      patch staff_tag_path(tag), params: { staff_tag: { published: "1" } }
      expect(tag.reload).to be_published
    end

    it "won't delete a tag that is still applied" do
      tag = create(:staff_tag)
      create(:staff_tagging, staff_tag: tag)

      expect {
        delete staff_tag_path(tag)
      }.not_to change(StaffTag, :count)
      expect(flash[:alert]).to be_present
    end
  end

  describe "as a non-admin" do
    before { sign_in create(:user, super_user: false) }

    it "forbids the index" do
      get staff_tags_path
      expect(response).not_to have_http_status(:ok)
    end
  end
end
