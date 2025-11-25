class AddAwsKeyToActiveStorageBlobs < ActiveRecord::Migration[8.1]
  def change
    add_column :active_storage_blobs, :aws_key, :string
  end
end
