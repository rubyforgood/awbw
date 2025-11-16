require "rails_helper"

RSpec.describe "/faqs", type: :request do
  let(:valid_attributes) do
    {
      question: "What is AWBW?",
      answer: "A Window Between Worlds (AWBW) uses art to heal trauma.",
      inactive: false
    }
  end

  let(:invalid_attributes) do
    {
      question: "",
      answer: "",
      inactive: nil
    }
  end

  let(:admin)         { create(:user, :admin) }
  let(:regular_user)  { create(:user) }
  let!(:active_faq)   { create(:faq, question: "Public FAQ", answer: "Public FAQ Body", inactive: false) }
  let!(:inactive_faq) { create(:faq, question: "Hidden FAQ", answer: "Hidden FAQ Body", inactive: true) }

  describe "GET /index" do
    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get faqs_path
        expect(response).to be_successful
      end

      it "shows all FAQs in the body" do
        get faqs_path
        expect(response.body).to include("Public FAQ")
        expect(response.body).to include("Hidden FAQ")
      end

      it "filters by inactive param" do
        get faqs_path, params: { inactive: true }
        expect(response.body).to include("Hidden FAQ")
        expect(response.body).not_to include("Public FAQ")
      end

      it "filters by query" do
        get faqs_path, params: { query: "Public" }
        expect(Faq.search_by_params(query: "Public").pluck(:question))
          .to include("Public FAQ")
        expect(Faq.search_by_params(query: "Public").pluck(:question))
          .not_to include("Hidden FAQ")
      end
    end

    context "as a non-admin user" do
      before { sign_in regular_user }

      it "renders successfully" do
        get faqs_path
        expect(response).to be_successful
      end

      it "shows only active FAQs" do
        get faqs_path
        expect(response.body).to include("Public FAQ")
        expect(response.body).not_to include("Hidden FAQ")
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

      it "redirects to the faqs index" do
        post faqs_url, params: { faq: valid_attributes }
        expect(response).to redirect_to(faqs_url)
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

      it "redirects to the faqs index" do
        patch faq_url(faq), params: { faq: new_attributes }
        expect(response).to redirect_to(faqs_url)
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
