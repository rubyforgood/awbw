module Publishable
  extend ActiveSupport::Concern

  included do
    scope :published, ->(flag = nil) do
      value = flag.nil? || flag == "" ? true : ActiveModel::Type::Boolean.new.cast(flag)
      where(published: value)
    end

    if column_names.include?("publicly_visible")
      scope :publicly_visible, -> { published.where(publicly_visible: true) }
    end
  end
end
