require "rails_helper"

RSpec.describe "POST /people", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "sector saving" do
    let!(:sector) { create(:sector, :published) }

    it "saves sectors via nested attributes on create" do
      post people_path, params: {
        skip_duplicate_check: "1",
        person: {
          first_name: "Sector",
          last_name: "Tester",
          created_by_id: admin.id,
          updated_by_id: admin.id,
          category_ids: [ "" ],
          sectorable_items_attributes: {
            "0" => { sector_id: sector.id, _destroy: "false" }
          }
        }
      }

      expect(Person.last.sectors).to include(sector)
    end

    it "saves sectors via nested attributes on update" do
      person = create(:person)

      patch person_path(person), params: {
        person: {
          first_name: person.first_name,
          category_ids: [ "" ],
          sectorable_items_attributes: {
            "0" => { sector_id: sector.id, _destroy: "false" }
          }
        }
      }

      person.reload
      expect(person.sectors).to include(sector)
    end

    it "preserves existing sectors when updating other fields" do
      person = create(:person)
      person.sectorable_items.create!(sector: sector)

      patch person_path(person), params: {
        person: {
          first_name: "Updated",
          category_ids: [ "" ]
        }
      }

      person.reload
      expect(person.sectors).to include(sector)
    end
  end

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
