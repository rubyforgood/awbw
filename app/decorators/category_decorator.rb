class CategoryDecorator < ApplicationDecorator
	def title
		name
	end

	def detail
		"#{category_type.name}: #{name}"
	end
end
