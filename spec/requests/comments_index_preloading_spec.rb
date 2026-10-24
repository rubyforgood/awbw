require "rails_helper"

# Each row's source chip walks its commentable to an event, form, person, or tag,
# so this guards the per-type preload: adding comments must not add queries.
RSpec.describe "Comments index preloading", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def create_comments_on_every_source
    author = create(:user, :with_person)
    scholarship = create(:scholarship)
    create(:allocation, source: scholarship, allocatable: create(:event_registration), amount: 500)
    [
      create(:person),
      create(:user, :with_person),
      create(:event_registration),
      scholarship,
      create(:continuing_education_registration),
      create(:topic_subscription),
      create(:form_submission, :with_event),
      create(:affiliation),
      create(:staff_tagging)
    ].each { |commentable| create(:comment, commentable: commentable, created_by: author, updated_by: author) }
  end

  def queries_for_results_frame
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    get comments_path, headers: { "Turbo-Frame" => "comments_results" }
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
