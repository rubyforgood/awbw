require "rails_helper"

# Each feed row's chip names the person behind the record and the event in its
# label. This guards the preload rather than a specific query count: more rows
# must not add queries.
RSpec.describe "Comment feed chip preloading", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  def add_comments(count, registrant: nil)
    count.times do
      registration = create(:event_registration, **{ registrant: registrant }.compact)
      scholarship = create(:scholarship, recipient: registration.registrant)
      create(:allocation, source: scholarship, allocatable: registration, amount: 0)
      ce = create(:continuing_education_registration, event_registration: registration)
      [ registration, scholarship, ce, registration.registrant ].each do |record|
        create(:comment, commentable: record, created_by: admin)
      end
    end
  end

  def queries_for(path, frame)
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    get path, headers: { "Turbo-Frame" => frame }
    ActiveSupport::Notifications.unsubscribe(subscriber)
    expect(response).to be_successful
    count
  end

  it "does not issue more queries on the everyone feed as more chips render" do
    add_comments(1)
    queries_for(comments_and_communications_path, "comments_and_communications_results")
    baseline = queries_for(comments_and_communications_path, "comments_and_communications_results")

    add_comments(3)
    expect(queries_for(comments_and_communications_path, "comments_and_communications_results")).to eq(baseline)
  end

  it "does not issue more queries on the everyone feed grouped by subject" do
    path = comments_and_communications_path(group_by_subject: 1)
    add_comments(1)
    queries_for(path, "comments_and_communications_results")
    baseline = queries_for(path, "comments_and_communications_results")

    add_comments(3)
    expect(queries_for(path, "comments_and_communications_results")).to eq(baseline)
  end

  it "does not issue more queries on /comments as more chips render" do
    add_comments(1)
    queries_for(comments_path, "comments_results")
    baseline = queries_for(comments_path, "comments_results")

    add_comments(3)
    expect(queries_for(comments_path, "comments_results")).to eq(baseline)
  end

  it "does not issue more queries on a person's all comments page as more chips render" do
    add_comments(1, registrant: person)
    queries_for(all_comments_person_path(person), "person_comments_results")
    baseline = queries_for(all_comments_person_path(person), "person_comments_results")

    add_comments(3, registrant: person)
    expect(queries_for(all_comments_person_path(person), "person_comments_results")).to eq(baseline)
  end
end
