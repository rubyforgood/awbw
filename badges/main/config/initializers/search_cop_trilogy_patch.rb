# config/initializers/search_cop_trilogy_patch.rb

require "search_cop/visitors/mysql"

module SearchCop
	module Visitors
		# Wrapper visitor for Trilogy
		class Trilogy
			def initialize(*args)
				@mysql_visitor = Mysql.new(*args)
			end

			# Delegate everything to Mysql
			def method_missing(name, *args, &block)
				if @mysql_visitor.respond_to?(name)
					@mysql_visitor.public_send(name, *args, &block)
				else
					super
				end
			end

			def respond_to_missing?(name, include_private = false)
				@mysql_visitor.respond_to?(name) || super
			end
		end
	end
end

# Monkey-patch ActiveRecord connection adapter detection
# Forces SearchCop to use Trilogy visitor for Trilogy connections
module SearchCop
	module Visitors
		class << self
			alias_method :original_visitor_for, :visitor_for if respond_to?(:visitor_for)

			def visitor_for(connection)
				if connection.adapter_name =~ /Trilogy/i
					Trilogy.new
				else
					original_visitor_for ? original_visitor_for(connection) : Mysql.new
				end
			end
		end
	end
end
