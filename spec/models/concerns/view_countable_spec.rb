# spec/models/concerns/view_countable_spec.rb
require "rails_helper"

RSpec.describe ViewCountable do
<<<<<<< HEAD
  let(:session) { {} }

  it "increments view_count once per session" do
    workshop = create(:workshop, view_count: 0)

    workshop.increment_view_count!(session: session, request: nil)
    workshop.increment_view_count!(session: session, request: nil)

    expect(workshop.reload.view_count).to eq(1)
  end

  it "tracks different models independently" do
    workshop = create(:workshop, view_count: 0)
    resource = create(:resource, view_count: 0)

    workshop.increment_view_count!(session: session, request: nil)
    resource.increment_view_count!(session: session, request: nil)

    expect(workshop.reload.view_count).to eq(1)
    expect(resource.reload.view_count).to eq(1)
  end
=======
	let(:session) { {} }

	it "increments view_count once per session" do
		workshop = create(:workshop, view_count: 0)

		workshop.increment_view_count!(session: session, request: nil)
		workshop.increment_view_count!(session: session, request: nil)

		expect(workshop.reload.view_count).to eq(1)
	end

	it "tracks different models independently" do
		workshop = create(:workshop, view_count: 0)
		resource = create(:resource, view_count: 0)

		workshop.increment_view_count!(session: session, request: nil)
		resource.increment_view_count!(session: session, request: nil)

		expect(workshop.reload.view_count).to eq(1)
		expect(resource.reload.view_count).to eq(1)
	end
>>>>>>> 34eaeec2 (Add view_count and download_count, print_count to models and controllers)
end
