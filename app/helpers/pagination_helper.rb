module PaginationHelper
	def tailwind_paginate(collection, options = {})
		will_paginate(
			collection,
			{
				renderer: TailwindPaginationRenderer,
				inner_window: 2,
				previous_label: "<<",
				next_label: ">>"
			}.merge(options)
		)
	end
end

