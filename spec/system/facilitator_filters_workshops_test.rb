require 'rails_helper'

RSpec.describe 'Facilitators can filter workshops using metadata' do
  describe "Workshop filtering" do
    context "when regular facilitator is logged in" do
      let(:user) { create(:user) }
      let(:adult_window) { create(:windows_type, :adult) }
      let(:child_window) { create(:windows_type, :children) }
      let(:combined_window) { create(:windows_type, :combined) }

      let(:sector_veterans) { create(:sector, :published, name: "Veterans & Military") }
      let(:sector_lgbtqia) { create(:sector, :published, name: "LGBTQIA") }
      let(:sector_child_abuse) { create(:sector, :published, name: "Child Abuse") }
      let(:sector_education) { create(:sector, :published, name: "Education/Schools") }

      before do
        create(:facilitator, user: user)

        # Create test workshops
        workshop_world = create(:workshop, title: 'The best workshop in the world', windows_type: adult_window, inactive: false)
        workshop_world.sectors << sector_veterans
        workshop_world.sectors << sector_education

        workshop_mars = create(:workshop, title: 'The best workshop on mars', windows_type: child_window, inactive: false)
        workshop_mars.sectors << sector_lgbtqia

        workshop_hello = create(:workshop, title: 'oh hello!', windows_type: combined_window, inactive: false)
        workshop_hello.sectors << sector_child_abuse

        workshop_combo = create(:workshop, title: 'Combined workshop', windows_type: combined_window, inactive: false)
        workshop_combo.sectors << sector_veterans
        workshop_combo.sectors << sector_lgbtqia
        workshop_combo.sectors << sector_education

        sign_in user
        visit workshops_path
      end

      it "shows workshops index page with filters" do
        expect(page).to have_content("Workshops")
        expect(page).to have_content('The best workshop in the world')
        expect(page).to have_content('oh hello!')
        expect(page).to have_content('The best workshop on mars')
        expect(page).to have_content('Windows Type')
        expect(page).to have_content('Service Population')
        expect(page).not_to have_content('Publish status')
      end

      it "filters by Adult window type" do
        find("#windows-types-button").click
        check "Adult"

        expect(page).to have_content('The best workshop in the world')
        expect(page).not_to have_content('The best workshop on mars')
        expect(page).not_to have_content('oh hello!')
      end

      it "filters by Children window type" do
        find("#windows-types-button").click
        check "Children"

        expect(page).to have_content('The best workshop on mars')
        expect(page).not_to have_content('The best workshop in the world')
        expect(page).not_to have_content('oh hello!')
      end

      it "filters by Combined window type" do
        find("#windows-types-button").click
        check "Combined"

        expect(page).to have_content('oh hello!')
        expect(page).to have_content('Combined workshop')
        expect(page).not_to have_content('The best workshop in the world')
        expect(page).not_to have_content('The best workshop on mars')
      end

      it "filters by multiple window types" do
        find("#windows-types-button").click
        check "Children"
        check "Combined"

        expect(page).to have_content('oh hello!')
        expect(page).to have_content('The best workshop on mars')
        expect(page).to have_content('Combined workshop')
        expect(page).not_to have_content('The best workshop in the world')
      end

      it "filters by Veterans & Military sector" do
        find("#sectors-button").click
        check "Veterans & Military"

        expect(page).to have_content('The best workshop in the world')
        expect(page).to have_content('Combined workshop')
        expect(page).not_to have_content('The best workshop on mars')
        expect(page).not_to have_content('oh hello!')
      end

      it "filters by LGBTQIA sector" do
        find("#sectors-button").click
        check "Lgbtqia"

        expect(page).to have_content('The best workshop on mars')
        expect(page).to have_content('Combined workshop')
        expect(page).not_to have_content('The best workshop in the world')
        expect(page).not_to have_content('oh hello!')
      end

      it "filters by Child Abuse sector" do
        find("#sectors-button").click
        check "Child Abuse"

        expect(page).to have_content('oh hello!')
        expect(page).not_to have_content('The best workshop in the world')
        expect(page).not_to have_content('The best workshop on mars')
        expect(page).not_to have_content('Combined workshop')
      end

      it "filters by multiple sectors" do
        find("#sectors-button").click
        check "Veterans & Military"
        check "Education/Schools"

        expect(page).to have_content('The best workshop in the world')
        expect(page).to have_content('Combined workshop')
        expect(page).not_to have_content('The best workshop on mars')
        expect(page).not_to have_content('oh hello!')
      end

      it "combines window type and sector filters" do
        find("#windows-types-button").click
        check "Adult"
        find("#sectors-button").click
        check "Veterans & Military"

        expect(page).to have_content('The best workshop in the world')
        expect(page).not_to have_content('Combined workshop')
        expect(page).not_to have_content('The best workshop on mars')
        expect(page).not_to have_content('oh hello!')
      end

      it "combines Combined window type with LGBTQIA sector" do
        find("#windows-types-button").click
        check "Combined"
        find("#sectors-button").click
        check "Lgbtqia"

        expect(page).to have_content('Combined workshop')
        expect(page).not_to have_content('The best workshop in the world')
        expect(page).not_to have_content('The best workshop on mars')
        expect(page).not_to have_content('oh hello!')
      end

      it "shows no results when filters match nothing" do
        find("#windows-types-button").click
        check "Adult"
        find("#sectors-button").click
        check "Child Abuse"

        expect(page).to have_content('WORKSHOPS (0)')
        expect(page).to have_content('Your search returned no results. Please try again.')
        expect(page).not_to have_content('The best workshop in the world')
        expect(page).not_to have_content('The best workshop on mars')
        expect(page).not_to have_content('oh hello!')
        expect(page).not_to have_content('Combined workshop')
      end
    end

    context "when super user facilitator is logged in" do
      let(:super_user) { create(:user, :admin) }
      let(:adult_window) { create(:windows_type, :adult) }
      let(:child_window) { create(:windows_type, :children) }
      let(:sector_veterans) { create(:sector, :published, name: "Veterans & Military") }
      let(:sector_lgbtqia) { create(:sector, :published, name: "LGBTQIA") }

      before do
        create(:facilitator, user: super_user)

        # Published workshop
        published_workshop = create(:workshop,
          title: 'Published Workshop',
          windows_type: adult_window,
          inactive: false)
        published_workshop.sectors << sector_veterans

        # Hidden workshop
        hidden_workshop = create(:workshop,
          title: 'Hidden Workshop',
          windows_type: child_window,
          inactive: true)
        hidden_workshop.sectors << sector_lgbtqia

        another_published = create(:workshop,
          title: 'Another Published Workshop',
          windows_type: adult_window,
          inactive: false)
        another_published.sectors << sector_lgbtqia

        sign_in super_user
        visit workshops_path
      end

      it "shows publish status filter for super user" do
        expect(page).to have_content('Publish status')
        expect(page).to have_content('Published Workshop')
        expect(page).to have_content('Another Published Workshop')
        expect(page).to have_content('Hidden Workshop')
      end

      it "filters to show only hidden workshops" do
        find("#published-button").click
        check "inactive_true"

        expect(page).to have_content('Hidden Workshop')
        expect(page).not_to have_content('Published Workshop')
        expect(page).not_to have_content('Another Published Workshop')
      end

      it "filters to show only published workshops" do
        find("#published-button").click
        check "inactive_false"

        expect(page).to have_content('Published Workshop')
        expect(page).to have_content('Another Published Workshop')
        expect(page).not_to have_content('Hidden Workshop')
      end

      it "combines publish status with sector filter" do
        find("#published-button").click
        check "inactive_true"
        find("#sectors-button").click
        check "Lgbtqia"

        expect(page).to have_content('Hidden Workshop')
        expect(page).not_to have_content('Published Workshop')
        expect(page).not_to have_content('Another Published Workshop')
      end
    end
  end
end
