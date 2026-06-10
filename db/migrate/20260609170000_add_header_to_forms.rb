class AddHeaderToForms < ActiveRecord::Migration[8.1]
  # Optional rich-text/HTML intro shown directly under the form title on the
  # internal preview and the public registration pages. NULL/blank means no
  # header is rendered.
  def up
    add_column :forms, :header, :text unless column_exists?(:forms, :header)
  end

  def down
    remove_column :forms, :header, if_exists: true
  end
end
