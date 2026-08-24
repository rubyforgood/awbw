require "rails_helper"

RSpec.describe Ahoy::Event do
  describe ".mutations" do
    it "keeps the events that changed the record" do
      %w[create.workshop update.workshop destroy.workshop].each do |name|
        create(:ahoy_event, name: name)
      end

      expect(described_class.mutations.pluck(:name))
        .to contain_exactly("create.workshop", "update.workshop", "destroy.workshop")
    end

    it "leaves out reads of the record" do
      %w[view.workshop print.workshop download.workshop search.workshops filter.workshops].each do |name|
        create(:ahoy_event, name: name)
      end

      expect(described_class.mutations).to be_empty
    end
  end
end
