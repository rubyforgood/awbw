require 'rails_helper'

RSpec.describe CategoryTypeDecorator do
  describe '#title' do
    it 'returns the name in sentence case' do
      category_type = build(:category_type, name: "art_type").decorate
      expect(category_type.title).to eq("Art type")
    end

    it 'capitalizes only the first word' do
      category_type = build(:category_type, name: "emotional_theme").decorate
      expect(category_type.title).to eq("Emotional theme")
    end
  end
end
