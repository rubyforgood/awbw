require "rails_helper"

# The results frame rolls up each org's sectors and age groups across its
# affiliated people (Organization#affiliated_people). Those roll-ups re-query per
# row unless the controller preloads people with the PEOPLE_TAGGINGS nest, so this
# guards the preload rather than a specific query count: adding orgs must not add
# queries.
RSpec.describe "Organizations index preloading", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:sector) { create(:sector, :published, name: "Housing") }
  let!(:age_type) { create(:category_type, name: "AgeRange", published: true) }
  let!(:teen) { create(:category, :published, category_type: age_type, name: "13-17") }

  before { sign_in admin }

  def create_orgs(count)
    count.times do |i|
      org = create(:organization, name: "Preload Org #{Organization.count}#{i}")
      person = create(:person)
      create(:affiliation, organization: org, person: person, title: "Facilitator")
      person.sectorable_items.create!(sector: sector, is_primary: true)
      person.tag_age_groups(primary_ids: [ teen.id ], additional_ids: [])
    end
  end

  def queries_for_results_frame
    Rails.cache.clear
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    get organizations_url, headers: { "Turbo-Frame" => "organizations_results" }
    ActiveSupport::Notifications.unsubscribe(subscriber)
    expect(response).to be_successful
    count
  end

  it "does not issue more queries as more organizations are listed" do
    create_orgs(2)
    baseline = queries_for_results_frame

    create_orgs(6)
    expect(queries_for_results_frame).to eq(baseline)
  end
end
