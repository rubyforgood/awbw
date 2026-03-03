require "rails_helper"

RSpec.describe WorkshopVariationIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_variation_idea
end
