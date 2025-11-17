require 'will_paginate/array'
WillPaginate.per_page = 12

Rails.application.config.to_prepare do
	require Rails.root.join("app/renderers/tailwind_pagination_renderer.rb")
	WillPaginate::ViewHelpers.pagination_options[:renderer] = TailwindPaginationRenderer
end
