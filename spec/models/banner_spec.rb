require 'rails_helper'

RSpec.describe Banner, type: :model do
  describe 'validations' do
    subject { build(:banner) }
    it { should validate_presence_of(:content) }

    it 'is invalid when ended_at is not after started_at' do
      banner = build(:banner, started_at: 1.day.from_now, ended_at: 1.day.ago)
      expect(banner).not_to be_valid
      expect(banner.errors[:ended_at]).to be_present
    end

    it 'is valid when only one bound of the window is set' do
      expect(build(:banner, started_at: 1.day.ago, ended_at: nil)).to be_valid
      expect(build(:banner, started_at: nil, ended_at: 1.day.from_now)).to be_valid
    end
  end

  describe '.active' do
    it 'includes published banners with no schedule window' do
      banner = create(:banner, published: true, started_at: nil, ended_at: nil)
      expect(Banner.active).to include(banner)
    end

    it 'excludes unpublished banners even when in window' do
      banner = create(:banner, published: false, started_at: 1.day.ago, ended_at: 1.day.from_now)
      expect(Banner.active).not_to include(banner)
    end

    it 'includes a published banner currently within its window' do
      banner = create(:banner, published: true, started_at: 1.day.ago, ended_at: 1.day.from_now)
      expect(Banner.active).to include(banner)
    end

    it 'excludes a published banner whose window has not started' do
      banner = create(:banner, published: true, started_at: 1.day.from_now, ended_at: 2.days.from_now)
      expect(Banner.active).not_to include(banner)
    end

    it 'excludes a published banner whose window has ended' do
      banner = create(:banner, published: true, started_at: 2.days.ago, ended_at: 1.day.ago)
      expect(Banner.active).not_to include(banner)
    end
  end
end
