require "rails_helper"

RSpec.describe "People authorization", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user, :with_person) }
  let(:other_person) { create(:person) }

  describe "GET /people" do
    context "as a visitor" do
      it "redirects to root" do
        get people_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get people_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get people_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /people/:id" do
    context "as a visitor" do
      it "redirects to root" do
        get person_path(other_person)
        expect(response).to redirect_to(root_path)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "redirects to root for another person" do
        get person_path(other_person)
        expect(response).to redirect_to(root_path)
      end

      it "renders successfully for own person" do
        get person_path(regular_user.person)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as an admin" do
      before { sign_in admin }

      it "renders successfully" do
        get person_path(other_person)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
