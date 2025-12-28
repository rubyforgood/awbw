# app/models/concerns/trendable.rb
module Trendable
	extend ActiveSupport::Concern

	included do
		scope :trending, ->(limit = 10) {
			order(Arel.sql(trending_sql)).limit(limit)
		}
	end

	class_methods do
		def trending_sql
			<<~SQL
        (
          view_count
          /
          POWER(
            GREATEST(EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600, 1),
            0.8
          )
        ) DESC
      SQL
		end
	end
end
