module Publishable
  extend ActiveSupport::Concern

  VISIBILITY_PARAMS = %i[
    published unpublished featured not_featured
    publicly_visible publicly_featured not_publicly_featured
  ].freeze

  included do
    scope :published, ->(flag = nil) do
      value = flag.nil? || flag == "" ? true : ActiveModel::Type::Boolean.new.cast(flag)
      where(published: value)
    end

    scope :publicly_visible, -> {
      # Only query DB when this scope is called
      column_names.include?("publicly_visible") ? published.where(publicly_visible: true) : published }
  end

  class_methods do
    # Combines checked visibility checkbox params with OR logic.
    # Returns the original scope when no visibility params are checked.
    def apply_visibility_filters(scope, params)
      conditions = []
      conditions << scope.published                                        if visibility_param_checked?(params, :published)
      conditions << scope.published(false)                                 if visibility_param_checked?(params, :unpublished)
      conditions << scope.published.where(featured: true)                  if visibility_param_checked?(params, :featured) && column_names.include?("featured")
      conditions << scope.where(featured: false)                           if visibility_param_checked?(params, :not_featured) && column_names.include?("featured")
      conditions << scope.publicly_visible                                 if visibility_param_checked?(params, :publicly_visible) && column_names.include?("publicly_visible")
      conditions << scope.publicly_visible.where(publicly_featured: true)  if visibility_param_checked?(params, :publicly_featured) && column_names.include?("publicly_featured")
      conditions << scope.publicly_visible.where(publicly_featured: false) if visibility_param_checked?(params, :not_publicly_featured) && column_names.include?("publicly_featured")

      return scope if conditions.empty?

      conditions.reduce { |combined, cond| combined.or(cond) }
    end

    def visibility_params_present?(params)
      VISIBILITY_PARAMS.any? { |key| visibility_param_checked?(params, key) }
    end

    private

    def visibility_param_checked?(params, key)
      params.key?(key) && ActiveModel::Type::Boolean.new.cast(params[key])
    end
  end
end
