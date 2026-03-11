require "rails_helper"

RSpec.describe "Workshop log card pagination on person profile", type: :system, js: true do
  let(:windows_type) { create(:windows_type, short_name: "Combined") }
  let(:organization) { create(:organization, name: "Test Org", windows_type_id: windows_type.id) }
  let(:workshop) { create(:workshop, :published, title: "Art Workshop", windows_type: windows_type) }
  let(:user) { create(:user) }
  let(:person) { create(:person, user: user, profile_show_workshop_logs: true) }

  before do
    create(:affiliation, person: person, organization: organization)
    sign_in user
  end

  context "with more than 5 logs for a workshop" do
    before do
      8.times do |i|
        create(:workshop_log,
          workshop_id: workshop.id,
          organization_id: organization.id,
          created_by_id: user.id,
          date: (i + 1).days.ago,
          adults_first_time: 1,
          adults_ongoing: 2)
      end
    end

    it "paginates date rows and allows navigation" do
      visit workshop_logs_person_path(person)

      within("[data-controller='paginated-fields']") do
        expect(page).to have_text("1 / 2")

        visible_items = all("[data-paginated-fields-target='item']:not(.hidden)")
        expect(visible_items.size).to eq(5)

        click_button "\u00BB"
        expect(page).to have_text("2 / 2")

        visible_items = all("[data-paginated-fields-target='item']:not(.hidden)")
        expect(visible_items.size).to eq(3)

        click_button "\u00AB"
        expect(page).to have_text("1 / 2")

        visible_items = all("[data-paginated-fields-target='item']:not(.hidden)")
        expect(visible_items.size).to eq(5)
      end
    end
  end

  context "with 5 or fewer logs for a workshop" do
    before do
      3.times do |i|
        create(:workshop_log,
          workshop_id: workshop.id,
          organization_id: organization.id,
          created_by_id: user.id,
          date: (i + 1).days.ago,
          adults_first_time: 1,
          adults_ongoing: 2)
      end
    end

    it "does not show pagination controls" do
      visit workshop_logs_person_path(person)

      within("[data-controller='paginated-fields']") do
        expect(page).not_to have_text("1 /")
      end
    end
  end
end
