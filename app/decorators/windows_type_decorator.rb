class WindowsTypeDecorator < Draper::Decorator
	delegate_all

	def title
		name
	end

	def description
		short_name
	end
end
