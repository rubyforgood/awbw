require "rails_helper"

RSpec.describe "Event registration search", type: :request do
  let(:admin) { create(:user, :admin) }

  def queries_during
    statements = []
    counter = ->(*, payload) { statements << payload[:sql] if payload[:sql].start_with?("SELECT") }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    statements
  end

  before do
    sign_in admin
    event = create(:event, title: "Spring training")
    3.times { create(:event_registration, event: event) }
  end

  %w[event_registration event_registration_dedupe].each do |model|
    it "labels #{model} results without a lookup per registration" do
      get "/search/#{model}", params: { q: "Spring" }

      statements = queries_during { get "/search/#{model}", params: { q: "Spring" } }

      expect(response.parsed_body.size).to eq(3)
      expect(statements.count { |sql| sql.include?("FROM `people`") }).to be <= 1
      expect(statements.count { |sql| sql.include?("FROM `events`") }).to be <= 1
    end
  end
end
