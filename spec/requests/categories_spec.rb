require 'rails_helper'

RSpec.describe "/categories", type: :request do
  let(:valid_attributes) do
    {
      name: "Test Category",
      category_type_id: create(:category_type).id,
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

  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe "GET /index" do
    it "renders a successful response" do
      Category.create! valid_attributes
      get categories_url
      expect(response).to be_successful
    end
  end

  describe "GET /show" do
    it "renders a successful response" do
      category = Category.create! valid_attributes
      get category_url(category)
      expect(response).to be_successful
    end
  end

  describe "GET /new" do
    it "renders a successful response" do
      get new_category_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    it "renders a successful response" do
      category = Category.create! valid_attributes
      get edit_category_url(category)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Category" do
        expect {
          post categories_url, params: { category: valid_attributes }
        }.to change(Category, :count).by(1)
      end

      it "redirects to categories index" do
        post categories_url, params: { category: valid_attributes }
        expect(response).to redirect_to(categories_url)
      end
    end

    context "with invalid parameters" do
      it "does not create a new Category" do
        expect {
          post categories_url, params: { category: invalid_attributes }
        }.to change(Category, :count).by(0)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post categories_url, params: { category: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    context "with valid parameters" do
      let(:new_attributes) do
        valid_attributes.merge(
          name: "Updated Category Name"
        )
      end

      it "updates the requested category" do
        category = Category.create! valid_attributes
        patch category_url(category), params: { category: new_attributes }
        category.reload
        skip("Add assertions for updated state")
      end

      it "redirects to the categories index" do
        category = Category.create! valid_attributes
        patch category_url(category), params: { category: new_attributes }
        category.reload
        expect(response).to redirect_to(categories_url)
      end
    end

    context "with ordering parameter (drag-and-drop)" do
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
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "handles update failures gracefully" do
        category_type = create(:category_type)
        category = create(:category, name: "Test", category_type: category_type, position: 1)
        # Mock update failure by finding and stubbing the specific instance
        allow(Category).to receive(:find).with(category.id.to_s).and_return(category)
        allow(category).to receive(:update).and_return(false)
        patch category_url(category), params: { position: 2 }
        expect(response).to have_http_status(:unprocessable_entity)
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
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        category = Category.create! valid_attributes
        patch category_url(category), params: { category: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the requested category" do
      category = Category.create! valid_attributes
      expect {
        delete category_url(category)
      }.to change(Category, :count).by(-1)
    end

    it "redirects to the categories list" do
      category = Category.create! valid_attributes
      delete category_url(category)
      expect(response).to redirect_to(categories_url)
    end
  end
end
