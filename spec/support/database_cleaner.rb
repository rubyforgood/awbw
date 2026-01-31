require 'database_cleaner/active_record'

RSpec.configure do |config|
	config.before(:suite) { DatabaseCleaner.clean_with(:truncation) }
	config.before(:each) { DatabaseCleaner.strategy = :transaction }
	config.before(:each, type: :system) { DatabaseCleaner.strategy = :truncation }
	config.before(:each) { DatabaseCleaner.start }
	config.after(:each)  { DatabaseCleaner.clean }
end
