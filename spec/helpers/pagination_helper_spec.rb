require "rails_helper"

RSpec.describe PaginationHelper, type: :helper do
  describe "#per_page_select_options" do
    it "selects the default when the URL has no size" do
      expect(helper.per_page_select_options(25)).to include('<option selected="selected" value="25">25</option>')
    end

    it "adds a URL size that isn't a preset, in order" do
      controller.params[:number_of_items_per_page] = "12"
      options = helper.per_page_select_options(25)

      expect(options.scan(/value="(\d+)"/).flatten).to eq(%w[10 12 25 50 100 250])
      expect(options).to include('<option selected="selected" value="12">12</option>')
    end

    it "falls back to the default for a size that isn't a positive number" do
      controller.params[:number_of_items_per_page] = "abc"

      expect(helper.per_page_select_options(25)).to include('<option selected="selected" value="25">25</option>')
    end
  end
end
