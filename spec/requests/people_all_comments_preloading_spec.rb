require "rails_helper"

# Same source-chip preload as the global comments index, scoped to one person's
# feed: adding comments on more of their records must not add queries.
RSpec.describe "Person all comments preloading", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  def create_comments_on_every_source
    author = create(:user, :with_person)
    registration = create(:event_registration, registrant: person)
    scholarship = create(:scholarship, recipient: person)
    create(:allocation, source: scholarship, allocatable: registration, amount: 500)
    [
      person,
      registration,
      scholarship,
      create(:continuing_education_registration, event_registration: registration),
      create(:topic_subscription, person: person),
      create(:form_submission, :with_event, person: person),
      create(:affiliation, person: person),
      create(:staff_tagging, staff_taggable: person)
    ].each { |commentable| create(:comment, commentable: commentable, created_by: author, updated_by: author) }
  end

  def queries_for_results_frame
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    get all_comments_person_path(person), headers: { "Turbo-Frame" => "person_comments_results" }
    ActiveSupport::Notifications.unsubscribe(subscriber)
    expect(response).to be_successful
    count
  end

  it "does not issue more queries as more comments are listed" do
    create_comments_on_every_source
    queries_for_results_frame
    baseline = queries_for_results_frame

    create_comments_on_every_source
    expect(queries_for_results_frame).to eq(baseline)
  end
end
