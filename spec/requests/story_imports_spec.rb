require "rails_helper"

RSpec.describe "Story imports", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  # Reference data the importer needs to resolve the fixture's real rows.
  before do
    create(:windows_type, :adult)
    create(:windows_type, :children)
    create(:windows_type, :combined)
    create(:organization_status, name: "Pending")
    # Sectors the fixture's categories map onto (see config/story_import_sector_mapping.yml).
    [
      "Self-Care/Personal Growth", "Domestic Violence", "Incarceration", "LGBTQIA+",
      "Substance Use/Recovery", "Community Engagement", "Racial/Social Justice",
      "Child Abuse/Neglect", "Mental Health", "Foster Care/Adoption"
    ].each { |name| create(:sector, name: name) }
  end

  let(:csv) { fixture_file_upload("spec/fixtures/files/stories_import.csv", "text/csv") }

  def signed_blob_for_fixture
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/stories_import.csv").open,
      filename: "stories_import.csv",
      content_type: "text/csv"
    ).signed_id
  end

  describe "GET /stories/import/new" do
    it "renders the upload form for admins" do
      sign_in admin
      get new_story_import_path

      expect(response).to be_successful
      expect(response.body).to include("Import stories from CSV")
    end

    it "redirects non-admins" do
      sign_in regular_user
      get new_story_import_path

      expect(response).to redirect_to(root_path)
    end

    it "redirects guests to sign in" do
      get new_story_import_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /stories/import (preview)" do
    before { sign_in admin }

    it "shows a dry-run preview without creating records" do
      post story_import_path, params: { file: csv }

      expect(StoryIdea.count).to eq(0)
      expect(Story.count).to eq(0)
      expect(response).to be_successful
      expect(response.body).to include("Preview import")
      expect(response.body).to include("Connected stories")
    end

    it "stashes the file as a blob so it can be confirmed" do
      expect {
        post story_import_path, params: { file: csv }
      }.to change(ActiveStorage::Blob, :count).by(1)
    end

    it "redirects with an alert when no file is given" do
      post story_import_path, params: {}

      expect(response).to redirect_to(new_story_import_path)
      expect(flash[:alert]).to match(/choose a csv/i)
    end

    it "rejects non-CSV uploads" do
      upload = fixture_file_upload("spec/fixtures/files/stories_import.csv", "image/png")
      allow(upload).to receive(:original_filename).and_return("avatar.png")

      post story_import_path, params: { file: upload }

      expect(response).to redirect_to(new_story_import_path)
      expect(flash[:alert]).to match(/not a csv/i)
    end

    it "is forbidden for non-admins" do
      sign_in regular_user
      post story_import_path, params: { file: csv }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /stories/import/confirm" do
    before { sign_in admin }

    # Every fixture row has a single-name facilitator (no last name), so each
    # becomes a Story-only record (a StoryIdea is created only for a resolvable,
    # non-AWBW author). The facilitator name is preserved as a comment.
    it "creates a Story for every row" do
      expect {
        post confirm_story_import_path, params: { signed_id: signed_blob_for_fixture }
      }.to change(Story, :count).by(10).and change(StoryIdea, :count).by(0)

      expect(response).to redirect_to(stories_path)
      expect(flash[:notice]).to match(/0 story ideas and 10 connected stories/)
    end

    it "tags stories with the sector their WordPress category maps to" do
      post confirm_story_import_path, params: { signed_id: signed_blob_for_fixture }

      expect(Story.find_by(title: "A Step in the Right Direction").sectors.pluck(:name)).to include("Domestic Violence")
      expect(Story.find_by(title: "Being Your True Self").sectors.pluck(:name)).to include("LGBTQIA+")
    end

    it "keeps a single-name facilitator as a comment on the story" do
      post confirm_story_import_path, params: { signed_id: signed_blob_for_fixture }

      story = Story.find_by(title: "A Step in the Right Direction")
      expect(story.comments.pluck(:body)).to include(a_string_matching(/Ashley/))
    end

    it "records the importing admin as the creator" do
      post confirm_story_import_path, params: { signed_id: signed_blob_for_fixture }

      expect(Story.last.created_by).to eq(admin)
    end

    it "redirects with an alert when the upload is gone" do
      post confirm_story_import_path, params: { signed_id: "bogus" }

      expect(response).to redirect_to(new_story_import_path)
      expect(flash[:alert]).to match(/no longer available/i)
    end
  end
end
