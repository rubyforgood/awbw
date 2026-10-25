# frozen_string_literal: true

require "rails_helper"

RSpec.describe FilemakerValues do
  describe "RETIRED_DUPLICATE_OF" do
    it "folds only retired organizations, each into one that isn't retired" do
      FilemakerValues::RETIRED_DUPLICATE_OF.each do |retired, original|
        expect(FilemakerValues::RETIRED_RECORDS).to include(retired)
        expect(FilemakerValues::RETIRED_RECORDS).not_to include(original)
      end
    end
  end

  it "renames only organizations it doesn't also leave out" do
    expect(FilemakerValues::RETIRED_RENAMED & FilemakerValues::RETIRED_RECORDS).to be_empty
  end
end
