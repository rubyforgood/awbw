require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:admin_user)   { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let!(:category_type) { create(:category_type) }

  let(:valid_attributes) do
    {
      name: "Test Category",
      category_type_id: category_type.id,
      published: true
    }
  end

  let(:invalid_attributes) do
    {
      name: "",                    # invalid: required
      category_type_id: nil,       # invalid: must exist
      published: nil               # invalid: boolean required
    }
  end

  # ============================================================
  # AS AN ADMIN
  # ============================================================

  context "as an admin" do
    before { sign_in admin_user }

    describe "GET index" do
      it "renders successfully" do
        create(:category, valid_attributes)
        get categories_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET show" do
      it "renders successfully" do
        category = create(:category, valid_attributes)
        get category_path(category)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET new" do
      it "renders successfully" do
        get new_category_path
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET edit" do
      it "renders successfully" do
        category = create(:category, valid_attributes)
        get edit_category_path(category)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "POST create" do
      context "with valid params" do
        it "creates a category" do
          expect {
            post categories_path, params: { category: valid_attributes }
          }.to change(Category, :count).by(1)

          expect(response).to redirect_to(categories_path)
        end
      end

      context "with invalid params" do
        it "does not create" do
          expect {
            post categories_path, params: { category: invalid_attributes }
          }.not_to change(Category, :count)

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe "PATCH update" do
      let!(:category) { create(:category, valid_attributes.merge(position: 1)) }

      context "with valid params" do
        it "updates attributes" do
          patch category_path(category),
                params: { category: { name: "Updated Name" } }

          expect(response).to have_http_status(:see_other)
          expect(category.reload.name).to eq("Updated Name")
        end
      end

      context "JSON ordering (drag & drop)" do
        it "updates the position of the category" do
          category_type = create(:category_type)
          category1 = create(:category, name: "First", category_type: category_type, position: 1)
          category2 = create(:category, name: "Second", category_type: category_type, position: 2)
          patch category_url(category2), params: { position: 1 }, as: :json
          category2.reload
          expect(response).to have_http_status(:ok)
          expect(category2.position).to be > 0
        end

        it "rejects invalid ordering values" do
          category_type = create(:category_type)
          category = create(:category, name: "Test", category_type: category_type, position: 1)
          patch category_url(category), params: { position: 0 }
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "handles update failures gracefully" do
          category_type = create(:category_type)
          category = create(:category, name: "Test", category_type: category_type, position: 1)
          # Mock update failure by finding and stubbing the specific instance
          allow(Category).to receive(:find).with(category.id.to_s).and_return(category)
          allow(category).to receive(:update).and_return(false)
          patch category_url(category), params: { position: 2 }
          expect(response).to have_http_status(:unprocessable_content)
        end


        it "scopes position updates by metadatum_id" do
          category_type1 = create(:category_type, name: "Type 1")
          category_type2 = create(:category_type, name: "Type 2")
          cat1_type1 = create(:category, name: "Cat1 Type1", category_type: category_type1, position: 1)
          cat2_type1 = create(:category, name: "Cat2 Type1", category_type: category_type1, position: 2)
          cat1_type2 = create(:category, name: "Cat1 Type2", category_type: category_type2, position: 1)
          # Update position of cat2_type1
          patch category_url(cat2_type1), params: { position: 1 }
          cat2_type1.reload
          cat1_type1.reload
          cat1_type2.reload
          # cat2_type1 should be moved to position 1
          expect(cat2_type1.position).to eq(1)
          # cat1_type2 should remain at position 1 since it's in a different scope
          expect(cat1_type2.position).to eq(1)
        end

        it "rejects invalid ordering value" do
          patch category_path(category),
                params: { position: 0 }

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "scopes ordering by category_type" do
          other_type = create(:category_type)

          cat1 = create(:category, category_type:, position: 1)
          cat2 = create(:category, category_type:, position: 2)
          cat_other_scope = create(:category, category_type: other_type, position: 1)

          patch category_path(cat2), params: { position: 1 }

          expect(cat2.reload.position).to eq(1)
          expect(cat_other_scope.reload.position).to eq(1)
        end

        it "handles update failure gracefully" do
          allow(Category).to receive(:find)
                               .with(category.id.to_s)
                               .and_return(category)

          allow(category).to receive(:update).and_return(false)

          patch category_path(category), params: { position: 2 }

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "with invalid attributes" do
        it "returns 422" do
          patch category_path(category),
                params: { category: invalid_attributes }

          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    describe "DELETE destroy" do
      it "destroys category" do
        category = create(:category, valid_attributes)

        expect {
          delete category_path(category)
        }.to change(Category, :count).by(-1)

        expect(response).to redirect_to(categories_path)
      end
    end
  end

  # ============================================================
  # AS A REGULAR USER
  # ============================================================

  context "as a regular user" do
    before { sign_in regular_user }

    it "denies index" do
      get categories_path
      expect(response).to redirect_to(root_path)
    end

    it "denies show" do
      category = create(:category, valid_attributes)
      get category_path(category)
      expect(response).to redirect_to(root_path)
    end

    it "denies new" do
      get new_category_path
      expect(response).to redirect_to(root_path)
    end

    it "denies edit" do
      category = create(:category, valid_attributes)
      get edit_category_path(category)
      expect(response).to redirect_to(root_path)
    end

    it "cannot create" do
      expect {
        post categories_path, params: { category: valid_attributes }
      }.not_to change(Category, :count)

      expect(response).to redirect_to(root_path)
    end

    it "cannot update" do
      category = create(:category, valid_attributes)
      patch category_path(category), params: { category: valid_attributes }
      expect(response).to redirect_to(root_path)
    end

    it "cannot destroy" do
      category = create(:category, valid_attributes)

      expect {
        delete category_path(category)
      }.not_to change(Category, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  # ============================================================
  # AS A GUEST
  # ============================================================

  context "as a guest" do
    it "denies index" do
      get categories_path
      expect(response).to redirect_to(root_path)
    end

    it "denies show" do
      category = create(:category, valid_attributes)
      get category_path(category)
      expect(response).to redirect_to(root_path)
    end

    it "denies new" do
      get new_category_path
      expect(response).to redirect_to(root_path)
    end

    it "cannot create" do
      post categories_path, params: { category: valid_attributes }
      expect(response).to redirect_to(root_path)
    end

    it "cannot destroy" do
      category = create(:category, valid_attributes)

      expect {
        delete category_path(category)
      }.not_to change(Category, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
