ActiveSupport.on_load(:active_storage) do
	host = Rails.application.routes.default_url_options[:host] || "http://localhost:3000"
	ActiveStorage::Current.url_options = { host: host }
end
