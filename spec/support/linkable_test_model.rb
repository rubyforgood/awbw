# spec/support/linkable_test_model.rb
class LinkableTestModel
	include ActiveModel::Model
	include Rails.application.routes.url_helpers
	include Linkable

	attr_accessor :id, :external_url_value

	def external_url
		external_url_value
	end

	# for internal link fallback
	def default_link_target
		"/fake/#{id}"
	end
end
