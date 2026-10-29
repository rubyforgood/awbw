# Solid Queue keeps its tables in a separate queue database (db/queue_schema.rb) that
# the test database doesn't have. Tag a group `:solid_queue` to build them around it.
module SolidQueueTables
  SCHEMA = Rails.root.join("db/queue_schema.rb")

  def self.create
    statements = SCHEMA.read.lines[1..-2].join
    connection.instance_eval(statements)
    reset_models
  end

  def self.drop
    connection.disable_referential_integrity do
      connection.tables.grep(/\Asolid_queue_/).each { |table| connection.drop_table(table) }
    end
    reset_models
  end

  def self.connection
    SolidQueue::Record.connection
  end

  def self.reset_models
    SolidQueue::Record.descendants.each(&:reset_column_information)
  end
end

RSpec.configure do |config|
  config.before(:context, :solid_queue) { SolidQueueTables.create }
  config.after(:context, :solid_queue) { SolidQueueTables.drop }
end
