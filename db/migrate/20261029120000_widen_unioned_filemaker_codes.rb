# filemaker_code is a growing set: imports and merges union codes onto one record, and a
# person the Rolodex lists ~35 times overflows varchar(255). Payments keep a single,
# indexed code, so they stay a string.
class WidenUnionedFilemakerCodes < ActiveRecord::Migration[8.1]
  TABLES = %i[people organizations affiliations addresses contact_methods].freeze

  def up
    TABLES.each { |table| change_column table, :filemaker_code, :text }
  end

  def down
    TABLES.each { |table| change_column table, :filemaker_code, :string }
  end
end
