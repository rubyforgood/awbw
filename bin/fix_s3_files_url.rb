require 'dotenv/load'
require 'active_record'
require 'aws/s3'

ActiveRecord::Base.establish_connection(
  :adapter  => "mysql2",
  :host     => "127.0.0.1",
  :username => "root",
  :database => "awbw_development",
  :encoding => "utf8"
)

module Ckeditor
end

class Ckeditor::Picture < ApplicationRecord
  self.table_name = "ckeditor_assets"
end

class FakePicture < Ckeditor::Picture
  self.table_name = "ckeditor_assets"
end

AWS::S3::Base.establish_connection!(
  :access_key_id     => ENV.fetch('AWS_ACCESS_KEY_ID'),
  :secret_access_key => ENV.fetch('AWS_SECRET_ACCESS_KEY'),
)

bucket = AWS::S3::Bucket.find(ENV.fetch('AWS_S3_BUCKET'))

bucket.objects.each do |s3_obj|

  if s3_obj.path.include? "/original" and s3_obj.content_type.include? "image"
    url  = s3_obj.url.split("?").first
    name = url.split("/").last

    puts "==> Updating #{url}..."

    p = FakePicture.new(data_file_name: name,
                        data_content_type: s3_obj.content_type,
                        actual_url: url)

    p.save(validate: false)

    p.type =  "Ckeditor::Picture"
    p.save(validate: false)
  end

end
