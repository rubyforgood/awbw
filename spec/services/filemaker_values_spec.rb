# frozen_string_literal: true

require "rails_helper"

RSpec.describe FilemakerValues do
  describe "RETIRED_DUPLICATE_OF" do
    it "folds only retired organizations, each into one that isn't retired" do
      FilemakerValues::RETIRED_DUPLICATE_OF.each do |retired, original|
        expect(FilemakerValues::RETIRED_RECORDS).to have_key(retired)
        expect(FilemakerValues::RETIRED_RECORDS).not_to have_key(original)
      end
    end
  end
end
