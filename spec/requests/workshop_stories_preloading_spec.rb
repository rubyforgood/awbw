require "rails_helper"

# The "Stories that use this workshop" cards render each story's rich-text body
# excerpt and display image, both of which re-query per row unless the controller
# preloads them. This guards the preload rather than a specific query count:
# linking more stories must not add queries.
RSpec.describe "Workshop stories preloading", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:workshop) { create(:workshop, published: true) }
  let(:frame_headers) { { "Turbo-Frame" => "show_lazy" } }

  before { sign_in admin }

  def link_stories(count)
    count.times do
      story = create(:story, :published, workshop: nil, title: "Preload story #{Story.count}")
      story.story_workshops.create!(workshop: workshop)
    end
  end

  def queries_for_show_frame
    Rails.cache.clear
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    get workshop_url(workshop), headers: frame_headers
    ActiveSupport::Notifications.unsubscribe(subscriber)
    expect(response).to be_successful
    count
  end

  it "does not issue more queries as more stories are linked" do
    link_stories(2)
    queries_for_show_frame
    baseline = queries_for_show_frame

    link_stories(6)
    expect(queries_for_show_frame).to eq(baseline)
  end
end
