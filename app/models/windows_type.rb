class WindowsType < ApplicationRecord
  # Associations
  has_many :workshops
  has_many :age_ranges
  has_many :reports
  has_many :form_builders

  def custom_label_method
    self.name.gsub("LOG", "").gsub("WORKSHOP", "WINDOWS").titleize.strip.gsub("Children", "Children's")
  end

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
      "Family"
    else
      name.gsub("LOG", "").gsub("WORKSHOP", "").strip
    end
  end

  def label
    label = ""
    if name.downcase.include?("combined")
      label = "Family Windows"
    else
      label = name.gsub("LOG", "").gsub("WORKSHOP", "WINDOWS").titleize.strip
    end
    label.gsub("Children", "Children's")
  end

  def workshop_log_label
    label = name.gsub("LOG", "").gsub("WORKSHOP", "").titleize.strip
    label.gsub("Children", "Children's").gsub("Adult & Children's","").gsub("(Family)", "").tr(' ','')
  end

  def log_label
    id != 3 ? "(#{name.split(' ')[0]})" : ''
  end

  private

  def self.symbolize(name)
    name.split(" ")[0]
        .gsub("'s", "")
        .downcase.to_sym
  end

  def self.defaults
    ['Women\'s Windows', 'Children\'s Windows',
     'Combined Women\'s and Children\'s Windows']
  end
end
