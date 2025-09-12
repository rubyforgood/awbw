Apipie.configure do |config|
  config.app_name                = 'Awbw'
  config.api_base_url            = '/api'
  config.doc_base_url            = '/api/v1/documentation'
  # where is your API defined?
  config.api_controllers_matcher = "#{Rails.root}/app/controllers/**/*.rb"
  config.app_info                = 'AWBW Member API for WordPress Site'
end
