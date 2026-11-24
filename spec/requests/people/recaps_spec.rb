require "rails_helper"

RSpec.describe "Person recaps", type: :request do
  let(:person) do
    create(:person, first_name: "Jordan", last_name: "Sample", email: "jordan.sample@example.com").tap do |record|
      create(:affiliation, person: record, title: "Facilitator", start_date: 1.year.ago)
    end
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "renders the standalone fallback page" do
      get person_recap_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jordan Sample")
      expect(response.body).to include("Recap content.")
    end

    it "answers a turbo stream request by filling the recap mount with the dialog" do
      get person_recap_path(person), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('<turbo-stream action="update" target="modal_mount">')
      expect(response.body).to include("<dialog")
      expect(response.body).to include("Jordan Sample")
      expect(response.body).to include(edit_person_path(person))
      expect(response.body).to include(comments_and_communications_path(person_id: person.id))
    end

    it "renders the recap trigger beside the person card on the people index" do
      person
      get people_path, headers: { "Turbo-Frame" => "people_results" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(person_recap_path(person))
      expect(response.body).to include("Recap for Jordan Sample")
    end
  end

  context "as a non-admin" do
    before { sign_in create(:user, :with_person) }

    it "redirects away instead of rendering the recap" do
      get person_recap_path(person)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("not authorized")
    end
  end
end
