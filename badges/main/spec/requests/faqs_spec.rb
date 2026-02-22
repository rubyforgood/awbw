require "rails_helper"

RSpec.describe "/faqs", type: :request do
  let(:valid_attributes) do
    {
      question: "What is AWBW?",
      answer: "A Window Between Worlds (AWBW) uses art to heal trauma.",
      published: true
    }
  end

  let(:invalid_attributes) do
    {
      question: "",
      answer: "",
      unpublished: nil
    }
  end

  let(:admin)            { create(:user, :admin) }
  let(:regular_user)     { create(:user) }
  let!(:published_faq)   { create(:faq, :published, question: "Published FAQ", answer: "Published FAQ Body") }
  let!(:unpublished_faq) { create(:faq, question: "Unpublished FAQ", answer: "Unpublished FAQ Body") }
  let!(:public_faq) { create(:faq, :published, question: "Public FAQ", answer: "Public FAQ Body", publicly_visible: true) }

  describe "GET /index" do
    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get faqs_path
        expect(response).to be_successful
      end

      it "shows all FAQs in the body" do
        get faqs_path
        expect(response.body).to include("Published FAQ")
        expect(response.body).to include("Unpublished FAQ")
      end

      it "filters by unpublished param" do
        get faqs_path, params: { published: "false" } # needs to be string param
        expect(response.body).to include("Unpublished FAQ")
        expect(response.body).not_to match(/>Published FAQ</)
      end

      it "filters by published query" do
        get faqs_path, params: { query: "Published" }
        expect(Faq.search_by_params(query: "Published").pluck(:question))
          .to include("Published FAQ")
        expect(Faq.search_by_params(query: "Unpublished").pluck(:question))
          .to include("Unpublished FAQ") # it should be case-insensitive
      end

      it "filters by title query" do
        get faqs_path, params: { query: "Published FAQ" }
        expect(Faq.search_by_params(query: "Published").pluck(:question))
          .to include("Published FAQ")
        expect(Faq.search_by_params(query: "Published").pluck(:question))
          .to include("Unpublished FAQ") # it should be case-insensitive, and unpublished FAQ includes Published

        expect(Faq.search_by_params(query: "Unpublished").pluck(:question))
          .to include("Unpublished FAQ")
      end
    end

    context "as a non-admin user" do
      before { sign_in regular_user }

      it "renders successfully" do
        get faqs_path
        expect(response).to be_successful
      end

      it "shows only published FAQs" do
        get faqs_path
        expect(response.body).to include("Published FAQ")
        expect(response.body).not_to include("Unpublished FAQ")
      end
    end

    context "as a guest" do
      it "renders successfully" do
        get faqs_path
        expect(response).to be_successful
      end

      it "shows only publicly_visible FAQs" do
        get faqs_path
        expect(response).to be_successful
        expect(response.body).to include("Public FAQ")
        expect(response.body).not_to include("Published FAQ")
        expect(response.body).not_to include("Unpublished FAQ")
      end
    end
  end

  describe "GET /show" do
    before { sign_in admin }

    it "renders a successful response" do
      faq = Faq.create!(valid_attributes)
      get faq_url(faq)
      expect(response).to be_successful
      expect(response.body).to include(faq.question)
      expect(response.body).to include(faq.answer)
    end
  end

  describe "GET /new" do
    before { sign_in admin }

    it "renders a successful response" do
      get new_faq_url
      expect(response).to be_successful
    end
  end

  describe "GET /edit" do
    before { sign_in admin }

    it "renders a successful response" do
      faq = Faq.create!(valid_attributes)
      get edit_faq_url(faq)
      expect(response).to be_successful
    end
  end

  describe "POST /create" do
    before { sign_in admin }

    context "with valid parameters" do
      before { sign_in admin }

      it "creates a new Faq" do
        expect {
          post faqs_url, params: { faq: valid_attributes }
        }.to change(Faq, :count).by(1)
      end

      it "redirects to the created faq" do
        post faqs_url, params: { faq: valid_attributes }
        expect(response).to redirect_to(faq_url(Faq.last))
      end
    end

    context "with invalid parameters" do
      before { sign_in admin }

      it "does not create a new Faq" do
        expect {
          post faqs_url, params: { faq: invalid_attributes }
        }.not_to change(Faq, :count)
      end

      it "renders a response with 422 status" do
        post faqs_url, params: { faq: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /update" do
    let(:faq) { Faq.create!(valid_attributes) }
    before { sign_in admin }

    context "with valid parameters" do
      let(:new_attributes) do
        { question: "Updated question?", answer: "Updated answer text." }
      end

      it "updates the requested faq" do
        patch faq_url(faq), params: { faq: new_attributes }
        faq.reload
        expect(faq.question).to eq("Updated question?")
        expect(faq.answer).to eq("Updated answer text.")
      end

      it "redirects to the faq" do
        patch faq_url(faq), params: { faq: new_attributes }
        expect(response).to redirect_to(faq_url(faq))
      end
    end

    context "with invalid parameters" do
      it "renders a 422 response" do
        patch faq_url(faq), params: { faq: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    before { sign_in admin }

    it "destroys the requested faq" do
      faq = Faq.create!(valid_attributes)
      expect {
        delete faq_url(faq)
      }.to change(Faq, :count).by(-1)
    end

    it "redirects to the faqs list" do
      faq = Faq.create!(valid_attributes)
      delete faq_url(faq)
      expect(response).to redirect_to(faqs_url)
    end
  end
end
