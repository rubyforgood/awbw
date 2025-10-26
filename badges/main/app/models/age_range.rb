class AgeRange < ApplicationRecord
  belongs_to :windows_type

  validates :name, presence: true, uniqueness: true

  def self.create_defaults
    AgeRange.defaults.each do |windows, ranges|
      windows_type = WindowsType.find_by(name: windows)
      ranges.each do |range|
        AgeRange.find_or_create_by(
          name: range,
          windows_type: windows_type
        )
      end
    end
  end

  private

  def self.defaults
    {
      'Children\'s Windows' => ['2-5', '6-12', '13-18', '19-24'],
      'Adult Windows' => ['Under 15', '25-35', '35-64', '65+']
    }
  end
end
