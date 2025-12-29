module WindowsTypeFilterable
  extend ActiveSupport::Concern

  included do
    scope :windows_type_name, ->(windows_type_name) do
      return all if windows_type_name.blank?

      normalized = normalize_windows_type_name(windows_type_name)

      joins(:windows_type)
        .where("LOWER(windows_types.short_name) LIKE ?", "%#{normalized}%")
    end
  end

  class_methods do
    def normalize_windows_type_name(value)
      value = value.to_s.downcase

      if value.include?("family") || value.include?("combined")
        "combined"
      elsif value.include?("child")
        "children"
      else
        "adult"
      end
    end
  end
end
