require 'rails_helper'

RSpec.describe "Facilitators can view Popular Resources on the dashboard" do
  describe "Facilitator views and navigates to Popular Resources" do
    context "when logged in" do
      before do
        @user = create(:user)
        create(:facilitator, user: @user)
        @popular_resource = create(:resource,
          title: "Most Popular Resource",
          featured: true,
          kind: "Scholarship"
        )

        @unpopular_resource = create(:resource,
          title: "Unpopular Resource",
          kind: "Template"
        )

        # Create Ahoy events to make the popular resource actually popular
        visit = create(:ahoy_visit)
        1000.times do
          create(:ahoy_event,
            visit: visit,
            name: "view.resource",
            properties: {
              resource_type: "Resource",
              resource_id: @popular_resource.id,
              resource_title: @popular_resource.title
            },
            time: rand(1..30).days.ago
          )
        end

        # Create just one event for the unpopular resource
        create(:ahoy_event,
          visit: visit,
          name: "view.resource",
          properties: {
            resource_type: "Resource",
            resource_id: @unpopular_resource.id,
            resource_title: @unpopular_resource.title
          },
          time: 1.day.ago
        )

        sign_in @user
        visit '/'
      end

      it "displays the Popular Resources section with the popular resource" do
        expect(page).to have_content("Popular Resources")
        expect(page).to have_content("Most Popular Resource")
        expect(page).not_to have_content("Unpopular Resource")
      end

      it "navigates to all resources page via 'Browse all resources' link and sees both resources" do
        click_link 'Browse all resources'
        expect(page).to have_current_path(resources_path)

        expect(page).to have_content("Most Popular Resource")
        expect(page).to have_content("Unpopular Resource")
      end

      it "navigates to a specific resource page by clicking its title" do
        click_link 'Most Popular Resource'
        expect(page).to have_current_path(resource_path(@popular_resource))
        expect(page).to have_content("Most Popular Resource")
      end
    end
  end
end
