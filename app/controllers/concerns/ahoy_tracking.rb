module AhoyTracking
  extend ActiveSupport::Concern

  def track(action, resource)
    Analytics::AhoyTracker.track(self, action, resource)
  end

  def track_event(name, properties = {})
    Analytics::AhoyTracker.track_event(self, name, properties)
  end

  def track_index_intent(resource_class, scope, params)
    result_count =
      if scope.respond_to?(:total_entries) # will_paginate
        scope.total_entries
      elsif scope.respond_to?(:count)
        count = scope.unscope(:select, :order).count
        count.is_a?(Hash) ? count.size : count
      else
        0
      end

    Analytics::AhoyTracker.track_index_intent(
      self,
      resource_class,
      params: params,
      result_count: result_count
    )
  end

  def track_tagging_browse(grouped_results)
    return unless ahoy&.visit_token

    sectors    = normalize_param_array(params[:sector_names_all])
    categories = normalize_param_array(params[:category_names_all])

    return if sectors.blank? && categories.blank?

    # Use each group's paginated total (total_entries) so this matches the
    # result_count the index searches record, not just the loaded page.
    result_count = grouped_results.values.sum { |r| r.respond_to?(:total_entries) ? r.total_entries : r.size }

    ahoy.track "search.taggings", {
      sectors: sectors,
      categories: categories,
      result_count: result_count
    }
  end

  # Sugar for controllers (readability)
  def track_view(resource, properties = {})
    if resource.is_a?(String)
      track_event("view.#{resource}", properties)
    else
      track(:view, resource)
    end
  end
  def track_print(resource)   = track(:print, resource)
  def track_download(resource)= track(:download, resource)

  def track_create(resource)  = track(:create, resource)
  def track_update(resource)  = track(:update, resource)
  def track_destroy(resource) = track(:destroy, resource)

  private

  def normalize_param_array(value)
    return [] if value.blank?
    Array(value).flat_map { |v| v.to_s.split(",") }.reject(&:blank?)
  end
end
