# frozen_string_literal: true
require "open-uri"
require_relative "../../config/environment"

puts "🚀 Starting Paperclip → ActiveStorage migration..."
puts "Environment: #{Rails.env}"

# Helper to detect and migrate Paperclip attachments
require "aws-sdk-s3"

def migrate_attachment(record, field)
	# Skip if already attached
	if record.respond_to?(field) && record.public_send(field).respond_to?(:attached?) &&
		record.public_send(field).attached?
		puts "⏭️  Skipping #{record.class}##{record.id} (already attached)"
		return
	end

	# Legacy Paperclip columns
	file_name = record.try("#{field}_file_name")
	content_type = record.try("#{field}_content_type")
	return puts("⏭️  Skipping #{record.class}##{record.id} (no legacy data)") if file_name.blank?

	# Build S3 public URL based on Paperclip structure
	key_path = record.id.to_s.rjust(9, "0").scan(/.{1,3}/).join("/")
	base_path = "#{record.class.table_name}/files/#{key_path}/original/#{file_name}"
	s3_url = "https://s3.amazonaws.com/awbwassets/#{base_path}"

	begin
		URI.open(s3_url) do |file_io|
			record.public_send(field).attach(
				io: file_io,
				filename: file_name,
				content_type: content_type || "application/octet-stream"
			)
		end
		puts "✅ Migrated #{record.class}##{record.id} (#{file_name})"
	rescue OpenURI::HTTPError => e
		puts "⚠️  #{record.class}##{record.id} — #{e.message} (#{s3_url})"
	rescue => e
		puts "⚠️  Failed #{record.class}##{record.id}: #{e.class} - #{e.message}"
	end
end




# Run migration for all configured models
Rails.application.reloader.wrap do
	MIGRATION_MAP = {
		User => [:avatar],
		Attachment => [:file],
		MediaFile => [:file],
		Image => [:file],
		Workshop => [:image],
		Resource => [:attachments, :images]
	}

	MIGRATION_MAP.each do |model, fields|
		puts "\nMigrating #{model}..."
		next unless ActiveRecord::Base.connection.table_exists?(model.table_name)

		model.find_each do |record|
			fields.each do |field|
				next unless record.respond_to?(field)
				migrate_attachment(record, field)
			end
		end
	end
end

puts "\n🎉 Migration complete!"
