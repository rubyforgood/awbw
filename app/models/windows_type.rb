class WindowsType < ApplicationRecord
  TYPES = ["Adult", "Children", "Combined"]

  has_many :workshops
  has_many :age_ranges
  has_many :reports
  has_many :form_builders

  # Methods
  def self.create_defaults
    WindowsType.defaults.each_with_index do |name, index|
      WindowsType.find_or_create_by(
        name: name,
        legacy_id: index + 1
      )
    end
  end

  def self.scopes
    pluck(:name).map do |name|
      symbolize(name)
    end
  end

  def short_name
    if name.include?("COMBINED")
      short_name = "Combined"
    else
      short_name = name.gsub("LOG", "").gsub("WORKSHOP", "").strip
    end
    short_name.titleize
  end

  def label
    label = short_name
    label = label.downcase.gsub("windows", "")
    label = label.downcase.gsub("workshop", "")
    label = label.downcase.gsub("log", "")
    label = label.gsub("Children", "Children's")
    label.strip.titleize
  end

  private

  def self.symbolize(name)
    name.split(" ")[0]
        .gsub("'s", "")
        .downcase.to_sym
  end

  def self.defaults # TODO - remove these
    ['Women\'s Windows', 'Children\'s Windows',
     'Combined Women\'s and Children\'s Windows']
  end
end
