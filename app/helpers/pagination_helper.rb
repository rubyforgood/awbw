module PaginationHelper
	def tailwind_paginate(collection, options = {})
		raw_collection =
			collection.respond_to?(:object) ? collection.object : collection

		will_paginate(
			raw_collection,
			{
				renderer: TailwindPaginationRenderer,
				inner_window: 2,
				previous_label: "<<",
				next_label: ">>"
			}.merge(options)
		)
	end
end
