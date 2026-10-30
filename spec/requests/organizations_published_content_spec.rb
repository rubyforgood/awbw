require "rails_helper"

RSpec.describe "Organization profile published content", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:viewer) { create(:user) }
  let(:organization) { create(:organization) }
  let(:facilitator) { create(:person) }

  # An active affiliation publishes the profile so non-admins can view it.
  before { create(:affiliation, organization: organization, person: facilitator) }

  describe "empty sections" do
    before { sign_in viewer }

    it "leaves the whole card off when there is nothing to list" do
      get organization_path(organization)

      expect(response.body).not_to include("Published content")
    end

    it "shows only the sections that have something to list" do
      create(:story, :published, organization: organization, title: "Only Story")

      get organization_path(organization)

      expect(response.body).to include("Published content")
      expect(response.body).to include("Only Story")
      expect(response.body).not_to include(">Workshops authored</h3>")
    end

    it "leaves a section off when only non-viewable records exist" do
      create(:story, :unpublished, organization: organization)

      get organization_path(organization)

      expect(response.body).not_to include("Published content")
    end
  end

  describe "Stories" do
    it "lists published stories linked to the organization" do
      create(:story, :published, organization: organization, title: "Linked Story")
      create(:story, :published, title: "Other Org Story")
      sign_in viewer

      get organization_path(organization)

      expect(response.body).to include("Linked Story")
      expect(response.body).not_to include("Other Org Story")
    end

    it "hides unpublished stories from non-admins but not admins" do
      create(:story, :unpublished, organization: organization, title: "Draft Story")

      sign_in viewer
      get organization_path(organization)
      expect(response.body).not_to include("Draft Story")

      sign_in admin
      get organization_path(organization)
      expect(response.body).to include("Draft Story")
    end

    # The first page renders with the profile, so its links must carry the section
    # themselves — the request that drew them had none.
    it "points the first page's pagination links at the section frame" do
      9.times { create(:story, :published, organization: organization) }
      sign_in viewer

      get organization_path(organization)

      links = Capybara.string(response.body).find("#organization_stories_section")
      expect(links).to have_link(href: organization_path(organization, section: "stories", page: 2))
    end

    it "serves later pages through the section frame" do
      create(:story, :published, organization: organization, title: "Paged Story")
      sign_in viewer

      get organization_path(organization, section: "stories"),
          headers: { "Turbo-Frame" => "organization_stories_section" }

      expect(response.body).to include("organization_stories_section")
      expect(response.body).to include("Paged Story")
    end

    it "refuses the section frame to non-admins when the org hides stories" do
      organization.update!(profile_show_stories: false)
      create(:story, :published, organization: organization, title: "Hidden Story")
      sign_in viewer

      get organization_path(organization, section: "stories"),
          headers: { "Turbo-Frame" => "organization_stories_section" }

      expect(response.body).not_to include("Hidden Story")
    end
  end

  describe "Workshops authored" do
    it "lists published workshops credited to an affiliated person" do
      create(:workshop, published: true, author: facilitator, title: "Authored Workshop")
      create(:workshop, published: true, created_by: create(:user, person: facilitator), title: "Legacy Workshop")
      create(:workshop, published: true, author: create(:person), title: "Outside Workshop")
      sign_in viewer

      get organization_path(organization)

      expect(response.body).to include("Authored Workshop")
      expect(response.body).to include("Legacy Workshop")
      expect(response.body).not_to include("Outside Workshop")
    end

    it "hides unpublished workshops from non-admins" do
      create(:workshop, published: false, author: facilitator, title: "Draft Workshop")
      sign_in viewer

      get organization_path(organization)

      expect(response.body).not_to include("Draft Workshop")
    end

    it "hides anonymously credited workshops from non-admins but not admins" do
      anonymous = create(:person, :anonymous_contributions)
      create(:affiliation, organization: organization, person: anonymous)
      create(:workshop, published: true, author: anonymous, title: "Profile Anonymous Workshop")
      create(:workshop, published: true, author: facilitator, author_credit_preference: "anonymous", title: "Item Anonymous Workshop")

      sign_in viewer
      get organization_path(organization)
      expect(response.body).not_to include("Profile Anonymous Workshop")
      expect(response.body).not_to include("Item Anonymous Workshop")

      sign_in admin
      get organization_path(organization)
      expect(response.body).to include("Profile Anonymous Workshop")
      expect(response.body).to include("Item Anonymous Workshop")
    end
  end

  describe "other org-linked content" do
    it "lists published community news, resources, and workshop variations linked to the org" do
      create(:community_news, :published, organization: organization, title: "Linked News")
      create(:resource, :published, organization: organization, title: "Linked Resource")
      create(:workshop_variation, :published, organization: organization, name: "Linked Variation")
      create(:community_news, :unpublished, organization: organization, title: "Draft News")
      create(:community_news, :published, title: "Other Org News")
      sign_in viewer

      get organization_path(organization)

      expect(response.body).to include(">Community news</h3>", "Linked News")
      expect(response.body).to include(">Resources</h3>", "Linked Resource")
      expect(response.body).to include(">Workshop variations</h3>", "Linked Variation")
      expect(response.body).not_to include("Draft News")
      expect(response.body).not_to include("Other Org News")
    end
  end

  describe "Events attended" do
    def get_events_section
      get organization_path(organization, section: "events"),
          headers: { "Turbo-Frame" => "organization_events_section" }
    end

    it "shows to everyone while the org shares it" do
      sign_in viewer
      get organization_path(organization)
      expect(response.body).to include("Events attended")
      expect(response.body).not_to include("only admins see this")
    end

    it "shows only to admins, marked admin-only, when the org hides it" do
      organization.update!(profile_show_events_registered: false)

      sign_in viewer
      get organization_path(organization)
      expect(response.body).not_to include("Events attended")
      get_events_section
      expect(response.body).not_to include("organization_events_section")

      sign_in admin
      get organization_path(organization)
      expect(response.body).to include("Events attended", "only admins see this")
      get_events_section
      expect(response.body).to include("organization_events_section")
    end
  end

  describe "Submitted content" do
    let(:member) { create(:user, person: facilitator) }
    let(:workshop) { create(:workshop, title: "Logged Workshop") }

    def submitted_card
      Capybara.string(response.body).find("h2", text: "Submitted content").ancestor("div.rounded-2xl", match: :first)
    end

    before do
      create(:workshop_log, organization: organization, workshop: workshop, adults_first_time: 3, teens_ongoing: 2)
      create(:workshop_log, organization: organization, workshop: workshop, adults_ongoing: 1)
    end

    it "groups the org's workshop logs by workshop for members" do
      sign_in member
      get organization_path(organization)

      expect(submitted_card).to have_text("Only visible to members and admins")
      expect(submitted_card).to have_text("Total participants: 6")
      expect(submitted_card).to have_text("Unique workshops: 1")
      expect(submitted_card).to have_link(href: workshop_logs_path(organization_id: organization.id, workshop_id: workshop.id))
    end

    it "stays off for non-members" do
      sign_in viewer
      get organization_path(organization)
      expect(response.body).not_to include("Submitted content")
    end

    it "hides workshop logs from members but not admins when the toggle is off" do
      organization.update!(profile_show_workshop_logs: false)

      sign_in member
      get organization_path(organization)
      expect(response.body).not_to include(">Workshop logs</h3>")

      sign_in admin
      get organization_path(organization)
      expect(response.body).to include(">Workshop logs</h3>")
    end

    it "lists ideas to admins only and monthly reports to members" do
      create(:story_idea, organization: organization, workshop: create(:workshop, title: "Org Story Idea"))
      create(:workshop_idea, title: "Org Workshop Idea", author: facilitator)
      create(:workshop_variation_idea, organization: organization, name: "Org Variation Idea")
      create(:monthly_report, organization: organization)

      sign_in member
      get organization_path(organization)
      expect(submitted_card).to have_text("Monthly reports")
      expect(submitted_card).to have_no_text("Org Story Idea")
      expect(submitted_card).to have_no_text("Org Workshop Idea")
      expect(submitted_card).to have_no_text("Org Variation Idea")

      sign_in admin
      get organization_path(organization)
      expect(submitted_card).to have_text("Org Story Idea")
      expect(submitted_card).to have_text("Org Workshop Idea")
      expect(submitted_card).to have_text("Org Variation Idea")
    end
  end

  describe "admin extras" do
    let(:member) { create(:user, person: facilitator) }

    it "leaves the associated-records chips off the profile" do
      sign_in admin
      get organization_path(organization)
      expect(response.body).not_to include("Associated records")
    end

    it "shows the Activity button to admins only" do
      activity_link = -> { Capybara.string(response.body).has_link?(href: /#{admin_activities_events_path}\?.*organization_id=#{organization.id}/) }

      sign_in member
      get organization_path(organization)
      expect(activity_link.call).to be(false)

      sign_in admin
      get organization_path(organization)
      expect(activity_link.call).to be(true)
    end

    it "shows the street address to admins only, as a locked chip" do
      create(:address, addressable: organization, street_address: "123 Sample Street")

      sign_in member
      get organization_path(organization)
      expect(response.body).not_to include("123 Sample Street")

      sign_in admin
      get organization_path(organization)
      chip = Capybara.string(response.body).find("[title='Street address (admin only)']")
      expect(chip[:class]).to include("admin-only")
      expect(chip).to have_text("123 Sample Street")
    end
  end
end
