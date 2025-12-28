# spec/models/concerns/view_countable_spec.rb
require "rails_helper"

RSpec.describe ViewCountable do
	let(:session) { {} }

	it "increments view_count once per session" do
		workshop = create(:workshop, view_count: 0)

		workshop.increment_view_count!(session: session, request: request)
		workshop.increment_view_count!(session: session, request: request)

		expect(workshop.reload.view_count).to eq(1)
	end

	it "tracks different models independently" do
		workshop = create(:workshop, view_count: 0)
		resource = create(:resource, view_count: 0)

		workshop.increment_view_count!(session: session, request: request)
		resource.increment_view_count!(session: session, request: request)

		expect(workshop.reload.view_count).to eq(1)
		expect(resource.reload.view_count).to eq(1)
	end
end
