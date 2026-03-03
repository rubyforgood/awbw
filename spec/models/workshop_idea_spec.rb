require 'rails_helper'

RSpec.describe WorkshopIdea, type: :model do
  it_behaves_like "author_creditable", factory: :workshop_idea
end
