module Publishable
  extend ActiveSupport::Concern

  included do
    scope :published, ->(flag = nil) do
      value = flag.nil? || flag == "" ? true : ActiveModel::Type::Boolean.new.cast(flag)
      where(published: value)
    end

    scope :publicly_visible, -> {
      # Only query DB when this scope is called
      if table_exists? && column_names.include?("publicly_visible")
        published.where(publicly_visible: true)
      else
        none
      end
    }
  end
end
