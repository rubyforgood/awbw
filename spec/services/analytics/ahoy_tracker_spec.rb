require "rails_helper"

RSpec.describe Analytics::AhoyTracker do
  describe ".extract_search_params (via track_index_intent)" do
    let(:user) { create(:user) }
    let(:category_type) { create(:category_type, :published, name: "ArtType") }
    let(:category) { create(:category, :published, name: "Drawing", category_type: category_type) }
    let(:sector) { create(:sector, :published, name: "Domestic Violence") }
    let(:windows_type) { create(:windows_type, :adult) }

    let(:controller) do
      instance_double(WorkshopsController).tap do |ctrl|
        ahoy = instance_double(Ahoy::Tracker, visit_token: "abc-123")
        allow(ctrl).to receive(:ahoy).and_return(ahoy)
        allow(ctrl).to receive(:current_user).and_return(user)
        allow(ahoy).to receive(:track)
        allow(ahoy).to receive(:visit).and_return(nil)
      end
    end

    it "captures categories from filter form param name" do
      params = ActionController::Parameters.new(
        "categories" => { category.id.to_s => category.id.to_s }
      )

      described_class.track_index_intent(
        controller, Workshop, params: params, result_count: 5
      )

      expect(controller.ahoy).to have_received(:track).with(
        "filter.workshops",
        hash_including(filters: hash_including(:categories))
      )
    end

    it "captures sectors from filter form param name" do
      params = ActionController::Parameters.new(
        "sectors" => { sector.id.to_s => sector.id.to_s }
      )

      described_class.track_index_intent(
        controller, Workshop, params: params, result_count: 5
      )

      expect(controller.ahoy).to have_received(:track).with(
        "filter.workshops",
        hash_including(filters: hash_including(:sectors))
      )
    end

    it "captures windows_types from filter form param name" do
      params = ActionController::Parameters.new(
        "windows_types" => { windows_type.id.to_s => windows_type.id.to_s }
      )

      described_class.track_index_intent(
        controller, Workshop, params: params, result_count: 5
      )

      expect(controller.ahoy).to have_received(:track).with(
        "filter.workshops",
        hash_including(filters: hash_including(:windows_types))
      )
    end

    it "still captures category_ids from edit form param name" do
      params = ActionController::Parameters.new(
        "category_ids" => [ category.id.to_s ]
      )

      described_class.track_index_intent(
        controller, Workshop, params: params, result_count: 5
      )

      expect(controller.ahoy).to have_received(:track).with(
        "filter.workshops",
        hash_including(filters: hash_including(:categories))
      )
    end

    it "includes query in search_zero events" do
      params = ActionController::Parameters.new(
        "query" => "music therapy"
      )

      described_class.track_index_intent(
        controller, Workshop, params: params, result_count: 0
      )

      expect(controller.ahoy).to have_received(:track).with(
        "search_zero.workshops",
        hash_including(query: "music therapy")
      )
    end

    it "does not fire search_zero when results exist" do
      params = ActionController::Parameters.new(
        "query" => "self care"
      )

      described_class.track_index_intent(
        controller, Workshop, params: params, result_count: 5
      )

      expect(controller.ahoy).not_to have_received(:track).with(
        "search_zero.workshops", anything
      )
    end
  end
end
