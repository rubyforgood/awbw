require "rails_helper"

RSpec.describe Membership::BulkAction do
  subject(:actions) { described_class.all }

  it "gives every registered action the full interface" do
    required = %i[key label unit param_name preview_rows perform notice]

    actions.each do |action|
      required.each do |method_name|
        expect(action).to respond_to(method_name),
          "#{action.class} must implement ##{method_name}"
      end
    end
  end

  it "requires the retry-compatible signatures" do
    actions.each do |action|
      expect(action.method(:preview_rows).parameters).to include([ :key, :ids ])
      expect(action.method(:perform).parameters).to include([ :keyreq, :ids ])
    end
  end

  it "keeps action keys unique" do
    expect(actions.map(&:key).uniq.size).to eq(actions.size)
  end
end
