module PrintCountable
	extend ActiveSupport::Concern

	def increment_print_count!
		increment!(:print_count)
	end
end
