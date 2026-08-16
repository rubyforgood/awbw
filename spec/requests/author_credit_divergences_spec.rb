require "rails_helper"

RSpec.describe "AuthorCreditDivergences", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:author_user) { create(:user, :with_person) }
  let(:person) { author_user.person }

  let!(:story) do
    person.update!(display_name_preference: "first_name_only")
    record = create(:story, created_by: author_user, author: person, author_credit_preference: nil)
    person.update!(display_name_preference: "full_name")
    record
  end

  describe "GET /author_credit_divergences" do
    it "requires an admin" do
      sign_in regular_user
      get author_credit_divergences_path
      expect(response).not_to have_http_status(:ok)
    end

    it "renders the page shell for an admin" do
      sign_in admin
      get author_credit_divergences_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Author credit divergences")
    end

    it "renders just the results inside the turbo frame" do
      sign_in admin
      get author_credit_divergences_path, headers: { "Turbo-Frame" => "author_credit_divergences_results" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person.full_name)
      expect(response.body).to include(story.title)
    end
  end

  describe "PATCH /author_credit_divergences/update_person" do
    before { sign_in admin }

    it "updates the profile and stamps the person reconciled" do
      patch update_person_author_credit_divergences_path,
            params: { id: person.id, person: { display_name_preference: "first_name_only", anonymous_contributions: "0" } }

      expect(person.reload.display_name_preference).to eq("first_name_only")
      expect(person.author_credit_reconciled_at).to be_present
    end

    it "can mark contributions anonymous" do
      patch update_person_author_credit_divergences_path,
            params: { id: person.id, person: { display_name_preference: "full_name", anonymous_contributions: "1" } }

      expect(person.reload.anonymous_contributions).to be(true)
      expect(story.reload.author_credit).to eq("AWBW Facilitator")
    end

    it "updates the results in place with a Turbo Stream instead of a full-page redirect" do
      patch update_person_author_credit_divergences_path,
            params: { id: person.id, person: { display_name_preference: "first_name_only", anonymous_contributions: "0" } },
            as: :turbo_stream

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include("author_credit_divergences_results")
    end

    it "carries the active filters through the redirect" do
      patch update_person_author_credit_divergences_path,
            params: { id: person.id, type: "Story",
                      person: { display_name_preference: "full_name", anonymous_contributions: "0" } }

      expect(response).to redirect_to(author_credit_divergences_path(type: "Story"))
    end

    it "rejects a non-admin" do
      sign_out admin
      sign_in regular_user
      patch update_person_author_credit_divergences_path,
            params: { id: person.id, person: { display_name_preference: "first_name_only" } }

      expect(person.reload.display_name_preference).to eq("full_name")
    end
  end

  describe "PATCH /author_credit_divergences/assign_author" do
    before { sign_in admin }

    let(:target) { create(:person, first_name: "Rosalind", last_name: "Franklin") }

    it "updates the results in place with a Turbo Stream instead of a full-page redirect" do
      workshop = create(:workshop, author: nil, full_name: "Marguerite Pre-Person")

      patch assign_author_author_credit_divergences_path,
            params: { record_type: "Workshop", record_id: workshop.id, author_id: target.id },
            as: :turbo_stream

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include("author_credit_divergences_results")
    end

    it "credits a legacy free-text record to a real person" do
      workshop = create(:workshop, author: nil, full_name: "Marguerite Pre-Person")

      patch assign_author_author_credit_divergences_path,
            params: { record_type: "Workshop", record_id: workshop.id, author_id: target.id }

      expect(workshop.reload.author).to eq(target)
      expect(workshop.author_credit).to eq("Rosalind Franklin")
    end

    it "credits a creator-fallback record so it links to the profile" do
      story = create(:story, created_by: author_user, author: nil)
      expect(story.author_credit_person).to be_nil

      patch assign_author_author_credit_divergences_path,
            params: { record_type: "Story", record_id: story.id, author_id: person.id }

      expect(story.reload.author_credit_person).to eq(person)
    end

    it "requires a person" do
      story = create(:story, created_by: author_user, author: nil)

      patch assign_author_author_credit_divergences_path,
            params: { record_type: "Story", record_id: story.id, author_id: "" }

      expect(flash[:alert]).to eq("Choose a person to credit.")
      expect(story.reload.author).to be_nil
    end

    it "refuses a type outside the allowlist" do
      patch assign_author_author_credit_divergences_path,
            params: { record_type: "User", record_id: admin.id, author_id: target.id }

      expect(flash[:alert]).to eq("Unknown record type.")
    end

    it "rejects a non-admin" do
      sign_out admin
      sign_in regular_user
      story = create(:story, created_by: author_user, author: nil)

      patch assign_author_author_credit_divergences_path,
            params: { record_type: "Story", record_id: story.id, author_id: target.id }

      expect(story.reload.author).to be_nil
    end
  end

  describe "PATCH /author_credit_divergences/update_item" do
    before { sign_in admin }

    it "rewrites a single record's stored snapshot" do
      patch update_item_author_credit_divergences_path,
            params: { record_type: "Story", record_id: story.id, author_credit_preference: "full_name" }

      expect(story.reload.author_credit_preference).to eq("full_name")
    end

    it "updates the results in place with a Turbo Stream instead of a full-page redirect" do
      patch update_item_author_credit_divergences_path,
            params: { record_type: "Story", record_id: story.id, author_credit_preference: "full_name" },
            as: :turbo_stream

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include("author_credit_divergences_results")
      expect(response.body).to include("flash_now")
    end

    it "clears the stored snapshot when set to blank, so the item just follows the profile" do
      story.update_column(:author_credit_preference, "last_name_only")

      patch update_item_author_credit_divergences_path,
            params: { record_type: "Story", record_id: story.id, author_credit_preference: "" }

      expect(story.reload.author_credit_preference).to be_nil
    end

    it "clears the snapshot of an item submitted anonymously, handing it to the profile" do
      story.update_column(:author_credit_preference, "anonymous")

      patch update_item_author_credit_divergences_path,
            params: { record_type: "Story", record_id: story.id, author_credit_preference: "" }

      expect(story.reload.author_credit_preference).to be_nil
      expect(story.author_credit).to eq(person.full_name)
    end

    it "suppresses one item's credit without touching the person's others" do
      other = create(:story, created_by: author_user, author: person)

      patch update_item_author_credit_divergences_path,
            params: { record_type: "Story", record_id: story.id, author_credit_preference: "anonymous" }

      expect(story.reload.author_credit).to eq("AWBW Facilitator")
      expect(other.reload.author_credit).to eq(person.full_name)
    end

    it "refuses a type outside the allowlist instead of constantizing it" do
      patch update_item_author_credit_divergences_path,
            params: { record_type: "User", record_id: admin.id, author_credit_preference: "anonymous" }

      expect(response).to redirect_to(author_credit_divergences_path)
      expect(flash[:alert]).to eq("Unknown record type.")
    end
  end
end
