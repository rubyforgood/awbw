# app/models/concerns/trendable.rb
module Trendable
  extend ActiveSupport::Concern

  included do
    scope :trending, ->(limit = 10) {
      # Get view counts from Ahoy events
      table_name_singular = table_name.singularize
      event_name = "view.#{table_name_singular}"
      # Subquery to count views per resource
      view_counts_subquery = Ahoy::Event
        .select("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id')) as resource_id, COUNT(*) as ahoy_view_count")
        .where(name: event_name)
        .group("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.resource_id'))")
        .to_sql
      # Join with the view counts and calculate trending score
      joins("LEFT JOIN (#{view_counts_subquery}) view_counts ON view_counts.resource_id = CAST(#{table_name}.id AS CHAR)")
        .select("#{table_name}.*, COALESCE(view_counts.ahoy_view_count, 0) as view_count")
        .order(Arel.sql(trending_sql))
        .limit(limit)
    }
  end

  class_methods do
    def trending_sql
      <<~SQL
        (
          COALESCE(view_counts.ahoy_view_count, 0)
          /
          POWER(
            GREATEST(EXTRACT(EPOCH FROM (NOW() - #{table_name}.created_at)) / 3600, 1),
            0.8
          )
        ) DESC
      SQL
    end
  end
end
