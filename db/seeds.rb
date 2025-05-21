# Resolve the correct DB credentials
config = YAML.load(ERB.new(File.read(Rails.root.join('config/database.yml'))).result)
env_config = config[Rails.env]

# Extract credentials
adapter = env_config['adapter']
host = env_config['host'] || 'localhost'
port = env_config['port'] || 3306
database = env_config['database']
username = env_config['username']
password = env_config['password']

# Only run if MySQL is the DB
if adapter.include?('mysql')
  sql_file = Rails.root.join('db', 'awbw_dml_only.sql')

  puts "Loading SQL dump from #{sql_file}..."

  # Build the shell command
  command = [
    "mysql",
    "-h", host.to_s,
    "-P", port.to_s,
    "-u", username.to_s,
    ("-p#{password}" if password.to_s.present?),
    database.to_s,
    "< #{sql_file}"
  ].compact.join(' ')

  # Run the command
  system(command) || raise("Failed to load SQL dump into #{database}")
  
  puts "SUCCESS! SQL dump loaded successfully."
else
  puts "Skipping SQL dump: not using MySQL (adapter = #{adapter})"
end

# wrapping in a tx for now
ActiveRecord::Base.transaction do
  # Load DML operations from dml_seeds.rb
  Admin.all.each { |a| a.update!(password: password) }

  User.all.find_in_batches(batch_size: 100) do |batch|
    batch.each { |u| u.update!(password: password) }
  end

  Admin.create!(first_name: "Amy", last_name: "Admin", email: "amy.admin@example.com", password: "password")
  User.create!(first_name: "Umberto", last_name: "User", email: "umberto.user@example.com", password: "password")
end
