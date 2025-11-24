require "csv"
require "aws-sdk-s3"
require "uri"

namespace :update_picture_urls do
  desc "Update picture URLs in all text columns for multiple models with optional start/end IDs"
  task update: :environment do
    run_update(dry_run: false)
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
      csv << ["model", "record_id", "column", "old_url", "aws_bucket", "aws_key", "status", "error"]

      models.each do |model|
        text_columns = model.columns.select { |c| c.type == :text }.map(&:name)
        puts "Processing #{model}"

        model.find_each(start: start_id, finish: finish_id) do |record|
          updated = false

          text_columns.each do |column|
            next unless record[column].present?

            new_content = record[column].gsub(/src="([^"]*)"/) do |match|
              url = match[/src="([^"]*)"/, 1]  # extract the actual URL

              aws_prefix = "https://s3.amazonaws.com/awbwassets/"

              # 1. Not an AWS URL we care about
              unless url.start_with?(aws_prefix)
                csv << [model.name, record.id, column, nil, url, nil, "skipped", "No AWS Url"]
                next match
              end

              # 2. Extract the S3 key
              # Example:
              #   "https://s3.amazonaws.com/awbwassets/home/devteam/file.jpg"
              # key -> "home/devteam/file.jpg"
              key = url.sub(aws_prefix, "")

              bucket = ENV["AWS_S3_BUCKET"]
              exists = true

              begin
                s3_client.head_object(bucket: bucket, key: key)
              rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
                exists = false
              end

              unless exists
                csv << [model.name, record.id, column, nil, url, nil, "skipped", "Key not found: #{key}"]
                next match
              end

              # 3. It’s a valid AWS file
              csv << [model.name, record.id, column, nil, url, key, dry_run ? "will_update" : "updated", nil]

              # do not replace URL yet
              match
            end

            if !dry_run && new_content != record[column]
              record[column] = new_content
              updated = true
            end
          end

          record.save! if updated && !dry_run
          puts "#{dry_run ? "Dry run" : "Updated"} #{model.name} ##{record.id}" if updated
        end
      end
    end
    puts "CSV report generated at #{csv_file}"
  end
end
