# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimelineServices::Router do
  let(:holder_class) do
    stub_const("SpecTimelineHolder", Class.new(ApplicationRecord) do
      self.table_name = "people"
      include HasTimeline
    end)
  end

  describe ".targets_for" do
    it "routes a record with a timeline to itself" do
      holder = holder_class.find(create(:person).id)

      expect(described_class.targets_for(holder)).to eq([ holder ])
    end

    it "routes records without timelines nowhere" do
      plain_class = stub_const("SpecPlainRecord", Class.new(ApplicationRecord) do
        self.table_name = "people"
      end)
      plain_record = plain_class.find(create(:person).id)

      expect(described_class.targets_for(plain_record)).to eq([])
    end
  end
end
