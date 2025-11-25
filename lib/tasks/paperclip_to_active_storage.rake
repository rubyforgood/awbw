# frozen_string_literal: true

require "aws-sdk-s3"
require "csv"

namespace :paperclip_to_active_storage do
  CSV_PATH = Rails.root.join("tmp/migration_log.csv")

  def s3_client
    Aws::S3::Client.new(
      region: ENV["AWS_REGION"],
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
      # ssl_ca_bundle: "/etc/ssl/certs/ca-certificates.crt"
    )
  end

  def migration_map
    {
      User => [:avatar],
      Attachment => [:file],
      MediaFile => [:file],
      Image => [:file],
      Workshop => [:thumbnail, :header],
      Report => [:form_file]
    }
  end

  def migrate_attachment(record, field)
    #  Skip if already attached
    if record.respond_to?(field) &&
        record.public_send(field).respond_to?(:attached?) &&
        record.public_send(field).attached?
      puts "⏭️  Skipping #{record.class}##{record.id} (already attached)"
      return {status: "skip", message: "already attached", key: ""}
    end

    file_name = record.try("#{field}_file_name")
    content_type = record.try("#{field}_content_type")

    if file_name.blank?
      puts "⏭️  Skipping #{record.class}##{record.id} (no legacy data)"
      return {status: "skip", message: "no legacy data", key: ""}
    end

    bucket = ENV["AWS_S3_BUCKET"]
    key_path = record.id.to_s.rjust(9, "0").scan(/.{1,3}/).join("/")

    key = case record.class.name
    when "MonthlyReport"
      "monthly_reports/#{field.to_s.pluralize}/#{key_path}/original/#{file_name}"
    when "Ckeditor::Picture"
      "ckeditor_assets/pictures/#{record.id}/original_#{File.basename(file_name, ".*")}#{File.extname(file_name)}"
    else
      "#{record.class.table_name}/#{field.to_s.pluralize}/#{key_path}/original/#{file_name}"
    end

    begin
      Tempfile.create(file_name) do |temp|
        temp.binmode

        # Download from S3
        s3_client.get_object(bucket: bucket, key: key) do |chunk|
          temp.write(chunk)
        end
        temp.rewind

        # Attempt attachment
        record.public_send(field).attach(
          io: temp,
          filename: file_name,
          content_type: content_type || "application/octet-stream"
        )
        # Verify attachment actually succeeded
        if record.public_send(field).attached?
          puts "✅ Migrated #{record.class}##{record.id} (#{file_name})"
          {status: "ok", message: "migrated", key: key}
        else
          puts "❌ Failed to attach #{record.class}##{record.id} (#{file_name})"
          {status: "error", message: "attachment_failed"}
        end
      end
    rescue Aws::S3::Errors::NoSuchKey
      puts "S3 says: no such key: #{key}"
      {status: "error", message: "NoSuchKey", key: key}
    rescue Aws::S3::Errors::AccessDenied
      puts "S3 says: access denied"
      {status: "error", message: "AccessDenied", key: key}
    rescue Aws::S3::Errors::ServiceError => e
      puts "S3 error: #{e.class} - #{e.message}"
      {status: "error", message: "#{e.class}: #{e.message}", key: key}
    rescue => e
      # Catch-all for unexpected errors
      puts "Unexpected error for #{record.class}##{record.id}: #{e.class} - #{e.message}"
      {status: "error", message: "#{e.class}: #{e.message}", key: key}
    end
  end

  def upload_csv(file_name)
    file_path = Rails.root.join("tmp/migration_log.csv")
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(file_path, "rb"),
      key: file_name,
      filename: file_name,
      content_type: "text/csv"
    )

    puts "\n Migration log uploaded to DigitalOcean as #{file_name}"
  end

  desc "Migrate Paperclip attachments to ActiveStorage (safe, manual-run only)"
  task migrate_to_active_storage: :environment do
    puts "🚀 Starting Paperclip → ActiveStorage migration..."
    puts "Environment: #{Rails.env}"
    puts "==============================================="

    Rails.application.reloader.wrap do
      CSV.open(CSV_PATH, "a") do |csv|
        csv << ["model", "id", "field", "file", "status", "message", "key"]
        migration_map.each do |model, fields|
          next unless ActiveRecord::Base.connection.table_exists?(model.table_name)

          puts "\n📦 Migrating #{model}..."

          model.find_each do |record|
            fields.each do |field|
              next unless record.respond_to?(field)
              result = migrate_attachment(record, field)
              csv << [
                model.name,
                record.id,
                field,
                record.try("#{field}_file_name"),
                result[:status],
                result[:message],
                result[:key]
              ]
            end

            # This should help with exceeding RAM on server
            if record.try("#{field}_file_name")
              GC.start(full_mark: true, immediate_sweep: true)
            end
          end
        end
      end

      upload_csv("migration_log_#{Time.now.to_i}.csv")
    end

    puts "\n🎉 Migration complete!"
  end

  desc "Dry run: check S3 for Paperclip attachments without migrating"
  task dry_run: :environment do
    puts "Starting dry run..."
    bucket = ENV["AWS_S3_BUCKET"]

    CSV.open(CSV_PATH, "w") do |csv|
      csv << ["model", "id", "field", "file_name", "reason", "key"]

      migration_map.each do |model, fields|
        next unless ActiveRecord::Base.connection.table_exists?(model.table_name)

        puts "\n📦 Checking #{model}..."
        model.find_each do |record|
          fields.each do |field|
            next unless record.respond_to?(field)

            file_name = record.try("#{field}_file_name")
            if file_name.blank?
              puts "⏭️  Skipping #{model}##{record.id} (no legacy file)"
              next
            end

            key_path = record.id.to_s.rjust(9, "0").scan(/.{1,3}/).join("/")

            key = case record.class.name
            when "MonthlyReport"
              "monthly_reports/#{field.to_s.pluralize}/#{key_path}/original/#{file_name}"
            when "Ckeditor::Picture"
              "ckeditor_assets/pictures/#{record.id}/original_#{File.basename(file_name, ".*")}#{File.extname(file_name)}"
            else
              "#{record.class.table_name}/#{field.to_s.pluralize}/#{key_path}/original/#{file_name}"
            end
            puts "Checking S3: #{key}"

            begin
              s3_client.head_object(bucket: bucket, key: key)
              puts "✅ Found #{model}##{record.id} (#{file_name})"
              csv << [model.name, record.id, field, file_name, nil, key]
            rescue Aws::S3::Errors::NoSuchKey
              puts "❌ Missing: #{model}##{record.id} (#{file_name})"
              csv << [model.name, record.id, field, file_name, "no such key", key]
            rescue Aws::S3::Errors::AccessDenied
              puts "❌ Access denied: #{model}##{record.id} (#{file_name})"
              csv << [model.name, record.id, field, file_name, "access denied", key]
            rescue Aws::S3::Errors::ServiceError => e
              puts "❌ S3 error: #{e.class} - #{e.message}"
              csv << [model.name, record.id, field, file_name, "#{e.class} - #{e.message}", key]
            end
          end
        end
      end
    end

    upload_csv("migration_dry_run_log_#{Time.now.to_i}.csv")

    puts "\n Dry run complete"
  end

  desc "Detach all ActiveStorage attachments for models in MIGRATION_MAP"
  task detach_attachments: :environment do
    puts " Detaching ActiveStorage attachments..."

    migration_map.each do |model, fields|
      next unless ActiveRecord::Base.connection.table_exists?(model.table_name)

      puts "\n Processing #{model}..."
      model.find_each do |record|
        fields.each do |attachment_name|
          next unless record.respond_to?(attachment_name)

          attachment = record.send(attachment_name)
          if attachment.attached?
            attachment.detach
            puts "Detached #{attachment_name} from #{model.name}##{record.id}"
          end
        end
      end
    end

    puts "\n All attachments detached!"
  end
end
