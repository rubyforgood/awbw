require "rails_helper"

RSpec.describe "/workshop_variations", type: :request do
  let(:regular_user) { create(:user) }
  let(:admin)        { create(:user, super_user: true) }
  let(:workshop)     { create(:workshop, published: true) }

  let(:valid_attributes) do
    {
      name: "Art Therapy Variation",
      rhino_body: "<p>A therapeutic approach to art-making.</p>",
      youtube_url: "https://www.youtube.com/watch?v=example",
      workshop_id: workshop.id,
      created_by_id: admin.id
    }
  end

  let(:invalid_attributes) do
    {
      name: "",
      rhino_body: ""
    }
  end

  # ============================================================
  # ADMIN - PROMOTION FROM WORKSHOP_VARIATION_IDEA
  # ============================================================

  context "as an admin promoting a workshop_variation_idea" do
    before { sign_in admin }

    let(:workshop_variation_idea) do
      create(:workshop_variation_idea,
             name: "Original Idea Name",
             rhino_body: "<p>Original idea body content</p>",
             youtube_url: "https://www.youtube.com/watch?v=idea",
             workshop: workshop)
    end

    describe "GET /new with workshop_variation_idea_id" do
      it "renders successfully" do
        get new_workshop_variation_path(workshop_variation_idea_id: workshop_variation_idea.id)
        expect(response).to have_http_status(:ok)
      end

      it "pre-populates the form with workshop_variation_idea data" do
        get new_workshop_variation_path(workshop_variation_idea_id: workshop_variation_idea.id)
        expect(response.body).to include(workshop_variation_idea.name)
        expect(response.body).to include("&lt;p&gt;Original idea body content&lt;/p&gt;")
      end
    end

    describe "POST /create from workshop_variation_idea" do
      it "creates a WorkshopVariation linked to the idea" do
        expect {
          post workshop_variations_path,
               params: {
                  workshop_variation: {
                    name: workshop_variation_idea.name,
                    rhino_body: workshop_variation_idea.rhino_body.body,
                   youtube_url: workshop_variation_idea.youtube_url,
                   workshop_id: workshop_variation_idea.workshop_id,
                   workshop_variation_idea_id: workshop_variation_idea.id,
                   created_by_id: admin.id
                 }
               }
        }.to change(WorkshopVariation, :count).by(1)

        new_variation = WorkshopVariation.last
        expect(new_variation.workshop_variation_idea_id).to eq(workshop_variation_idea.id)
        expect(new_variation.name).to eq(workshop_variation_idea.name)
        expect(response).to redirect_to(workshop_variation_path(WorkshopVariation.last))
      end

      it "attaches assets from idea when promote_idea_assets is true" do
        # Create an idea with a primary asset
        idea_with_asset = create(:workshop_variation_idea, workshop: workshop)
        primary_asset = PrimaryAsset.create!(
          owner: idea_with_asset,
          file: fixture_file_upload("spec/fixtures/files/sample.png", "image/png")
        )

        expect {
          post workshop_variations_path,
               params: {
                 workshop_variation: {
                    name: idea_with_asset.name,
                    rhino_body: idea_with_asset.rhino_body.body,
                   workshop_id: idea_with_asset.workshop_id,
                   workshop_variation_idea_id: idea_with_asset.id,
                   created_by_id: admin.id
                 },
                 promote_idea_assets: "true"
               }
        }.to change(WorkshopVariation, :count).by(1)

        new_variation = WorkshopVariation.last
        expect(new_variation.assets.count).to be > 0
      end

      it "does not duplicate assets if promote_idea_assets is false" do
        idea_with_asset = create(:workshop_variation_idea, workshop: workshop)
        primary_asset = PrimaryAsset.create!(
          owner: idea_with_asset,
          file: fixture_file_upload("spec/fixtures/files/sample.png", "image/png")
        )

        post workshop_variations_path,
             params: {
               workshop_variation: {
                  name: idea_with_asset.name,
                  rhino_body: idea_with_asset.rhino_body.body,
                 workshop_id: idea_with_asset.workshop_id,
                 workshop_variation_idea_id: idea_with_asset.id,
                 created_by_id: admin.id
               }
             }

        new_variation = WorkshopVariation.last
        expect(new_variation.assets.count).to eq(0)
      end
    end

    describe "WorkshopVariationIdea association" do
      it "tracks which workshop_variations were created from an idea" do
        post workshop_variations_path,
             params: {
               workshop_variation: {
                  name: workshop_variation_idea.name,
                  rhino_body: workshop_variation_idea.rhino_body.body,
                 workshop_id: workshop_variation_idea.workshop_id,
                 workshop_variation_idea_id: workshop_variation_idea.id,
                 created_by_id: admin.id
               }
             }

        workshop_variation_idea.reload
        expect(workshop_variation_idea.workshop_variations.count).to eq(1)
        expect(workshop_variation_idea.workshop_variations.first.name).to eq(workshop_variation_idea.name)
      end
    end
  end

  # ============================================================
  # ADMIN - NORMAL CRUD
  # ============================================================

  context "as an admin" do
    before { sign_in admin }

    describe "GET /index" do
      it "renders successfully" do
        create(:workshop_variation, valid_attributes)
        get workshop_variations_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /new" do
      it "renders successfully" do
        get new_workshop_variation_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST /create" do
      context "with valid params" do
        it "creates a WorkshopVariation" do
          expect {
            post workshop_variations_path, params: { workshop_variation: valid_attributes }
          }.to change(WorkshopVariation, :count).by(1)

          expect(response).to redirect_to(workshop_variation_path(WorkshopVariation.last))
        end
      end

      context "with invalid params" do
        it "does not create and renders new" do
          expect {
            post workshop_variations_path, params: { workshop_variation: invalid_attributes }
          }.not_to change(WorkshopVariation, :count)

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Unable to save the workshop variation")
        end
      end
    end

    describe "GET /edit" do
      it "renders successfully" do
        variation = create(:workshop_variation, valid_attributes)
        get edit_workshop_variation_path(variation)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "PATCH /update" do
      it "updates the workshop variation" do
        variation = create(:workshop_variation, valid_attributes)

        patch workshop_variation_path(variation),
              params: { workshop_variation: { name: "Updated Name" } }

        expect(variation.reload.name).to eq("Updated Name")
        expect(response).to redirect_to(workshop_variation_path(variation))
      end
    end
  end

  # ============================================================
  # REGULAR USER
  # ============================================================

  context "as a regular user" do
    before { sign_in regular_user }

    describe "GET /index" do
      it "renders successfully" do
        get workshop_variations_path
        expect(response).to be_successful # it's a hidden route
      end
    end

    describe "GET /new" do
      it "redirects to root" do
        get new_workshop_variation_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "creates a WorkshopVariation" do
        expect {
          post workshop_variations_path,
               params: { workshop_variation: valid_attributes.merge(created_by_id: regular_user.id) }
        }.to_not change(WorkshopVariation, :count)
      end
    end
  end
end
