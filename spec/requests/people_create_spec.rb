require "rails_helper"

RSpec.describe "POST /people", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "user_attributes are applied on create" do
    it "updates the user's time_zone from the person form" do
      user = create(:user, time_zone: "Hawaii")

      post people_path, params: {
        skip_duplicate_check: "1",
        person: {
          first_name: user.first_name,
          last_name: user.last_name,
          email: user.email,
          created_by_id: admin.id,
          updated_by_id: admin.id,
          user_attributes: {
            id: user.id,
            time_zone: "Eastern Time (US & Canada)"
          }
        }
      }

      expect(response).to redirect_to(Person.last)
      expect(user.reload.time_zone).to eq("Eastern Time (US & Canada)")
    end
  end
end
