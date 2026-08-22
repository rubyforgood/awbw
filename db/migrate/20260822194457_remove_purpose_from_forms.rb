class RemovePurposeFromForms < ActiveRecord::Migration[8.1]
  # The agreement scenario moved off the form record: a standalone
  # registration-role form IS the on-demand agreement, and new_job /
  # reinstatement are form roles (ADR-0002). Nothing in production ever
  # stored a purpose.
  def change
    remove_column :forms, :purpose, :string
  end
end
