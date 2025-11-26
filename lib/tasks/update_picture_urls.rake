require "csv"
require "aws-sdk-s3"

include Rails.application.routes.url_helpers

namespace :update_picture_urls do
  desc "Update picture URLs in all text columns for multiple models with optional start/end IDs"
  task :update, [:start_id, :finish_id] => :environment do |t, args|
    run_update(
      dry_run: false,
      start_id: args[:start_id]&.to_i,
      finish_id: args[:finish_id]&.to_i
    )
  end

  desc "Dry run: check picture URLs without updating, generate CSV report"
  task dry_run: :environment do
    run_update(dry_run: true)
  end

  def s3_client
    Aws::S3::Client.new(
      region: ENV["AWS_REGION"],
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
      ssl_ca_bundle: "/etc/ssl/certs/ca-certificates.crt"
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

  def run_update(dry_run:, start_id: nil, finish_id: nil)
    models = [
      Address,
      AgeRange,
      AnswerOption,
      Attachment,
      Banner,
      Bookmark,
      Category,
      CategorizableItem,
      CommunityNews,
      EventRegistration,
      Event,
      Facilitator,
      Faq,
      FormBuilder,
      FormFieldAnswerOption,
      FormField,
      Form,
      Image,
      Location,
      MediaFile,
      Metadatum,
      MonthlyReport,
      Notification,
      ProjectObligation,
      ProjectStatus,
      ProjectUser,
      Project,
      QuotableItemQuote,
      Quote,
      ReportFormFieldAnswer,
      Report,
      Resource,
      SectorableItem,
      Sector,
      Story,
      StoryIdea,
      UserFormFormField,
      UserForm,
      User,
      WindowsType,
      WorkshopAgeRange,
      WorkshopIdea,
      WorkshopLog,
      WorkshopResource,
      WorkshopSeriesMembership,
      WorkshopVariation,
      Workshop
    ]

    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    csv_file = Rails.root.join("tmp", dry_run ? "dry_run_picture_urls_#{timestamp}.csv" : "updated_picture_urls_#{timestamp}.csv")

    CSV.open(csv_file, "w") do |csv|
      csv << ["model", "record_id", "column", "old_url", "aws_key", "status", "error", "replacement_url"]

      models.each do |model|
        text_columns = model.columns.select { |c| c.type == :text }.map(&:name)
        puts "Processing #{model}..........................................................................................."

        model.find_each(start: start_id, finish: finish_id) do |record|
          puts "Processing #{model} id: #{record.id}"
          text_columns.each do |column|
            next unless record[column].present?

            process_content(model, record, column, dry_run, csv)
          end
        end
      end
    end

    upload_csv("rich_text_update_log_#{Time.now.to_i}.csv", csv_file)
    puts "CSV report generated at #{csv_file}"
  end

  def process_content(model, record, column, dry_run, csv)
    record.public_send(column).gsub(/src="([^"]*)"/) do |match|
      url = match[/src="([^"]*)"/, 1] # extract the actual URL
      aws_prefix = "https://s3.amazonaws.com/awbwassets/"
      aws_prefix_2 = "http://s3.amazonaws.com/awbwassets/"
      dashboard_url = nil
      key = nil
      puts url
      case url
      when %r{^/awbw/} # matches any URL starting with /awbw/uploads/
        dashboard_url = "https://dashboard.awbw.org#{url}"
        key = url
      when ->(u) { u.start_with?("https://dashboard.awbw.org") } # https
        key = url.sub(%r{^https://dashboard\.awbw\.org}, "")
        dashboard_url = url
      when ->(u) { u.start_with?("http://dashboard.awbw.org") }
        key = url.sub(%r{^http://dashboard\.awbw\.org}, "")
        dashboard_url = "https://dashboard.awbw.org#{key}"
      when ->(u) { u.start_with?("https://legacy.awbw.org") }
        key = url.sub(%r{^https://legacy\.awbw\.org}, "")
        dashboard_url = "https://dashboard.awbw.org#{key}"
      when ->(u) { u.start_with?("http://legacy.awbw.org") }
        key = url.sub(%r{^http://legacy\.awbw\.org}, "")
        dashboard_url = "https://dashboard.awbw.org#{key}"
      when ->(u) { u.start_with?(aws_prefix) } # matches URLs starting with the AWS prefix
        key = url.sub(aws_prefix, "")
      when ->(u) { u.start_with?(aws_prefix_2) }
        key = url.sub(aws_prefix_2, "")
      else
        csv << [model.name, record.id, column, url, nil, "skipped", "No AWS Url", nil]
        next
      end

      # Extract the S3 key
      bucket = ENV["AWS_S3_BUCKET"]
      if dry_run
        begin
          s3_client.head_object(bucket: bucket, key: key)
          csv << [model.name, record.id, column, url, key, "success", nil, nil]
        rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
          csv << [model.name, record.id, column, url, key, "skipped", "Key not found", nil]
        end
        next
      end

      begin
        blob = ActiveStorage::Blob.find_by(aws_key: key)
        image = record.images.build(type: "Images::RichText")
        file_name = File.basename(key)
        temp = nil

        ActiveRecord::Base.transaction do
          unless blob
            temp = if dashboard_url
              # Download from previous production local storage
              URI.open(dashboard_url)
            else
              Tempfile.new(file_name)
            end
            temp.binmode
            # Download from S3
            unless dashboard_url
              s3_client.get_object(bucket: bucket, key: key) do |chunk|
                temp.write(chunk)
              end
            end
            temp.rewind

            content_type = Marcel::MimeType.for temp
            blob = ActiveStorage::Blob.create_and_upload!(
              io: temp,
              filename: file_name,
              content_type: content_type
            )
            blob.update!(aws_key: key)
          end
          image.file.attach(blob)
          image.save!

          new_url = url_for(image.file)

          # Verify attachment and association
          record.images.reload
          unless record.images.include?(image) && image.file.attached?
            raise "Image not associated with record or file missing"
          end
          content = record.public_send(column)
          new_content = content.gsub(url, new_url)
          record.update_column(column, new_content)
          # Log success
          puts "#{model.name} # #{record.id} updated"
          csv << [model.name, record.id, column, url, key, "updated", nil, new_url]
        end
      rescue => e
        csv << [model.name, record.id, column, url, key, "error", "#{e.class}: #{e.message}", nil]
      ensure
        temp&.close
      end
    end
  end
end
