def s3_client
  Aws::S3::Client.new(
    region: ENV["AWS_REGION"],
    access_key_id: ENV["AWS_ACCESS_KEY_ID"],
    secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
    # ssl_ca_bundle: "/etc/ssl/certs/ca-certificates.crt"
  )
end

def upload_csv(file_name, csv_file)
  file_path = Rails.root.join(csv_file)
  ActiveStorage::Blob.create_and_upload!(
    io: File.open(file_path, "rb"),
    key: file_name,
    filename: file_name,
    content_type: "text/csv"
  )

  puts "\n Migration log uploaded to DigitalOcean as #{file_name}"
end
