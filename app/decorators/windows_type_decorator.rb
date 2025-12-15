class WindowsTypeDecorator < ApplicationDecorator

	def title
		name
	end

	def detail
		short_name
	end
end
