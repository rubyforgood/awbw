require "csv"

namespace :attachment_report do
  desc "Scan text columns for attachments and log all URLs to CSV"
  task scan: :environment do
    run_attachment_report
  end

  def run_attachment_report(start_id: nil, finish_id: nil)
    models = [
      Address, AgeRange, AnswerOption, Attachment, Banner, Bookmark,
      Category, CategorizableItem, CommunityNews, EventRegistration, Event,
      Facilitator, Faq, FormBuilder, FormFieldAnswerOption, FormField, Form,
      Image, Location, MediaFile, Metadatum, MonthlyReport, Notification,
      ProjectObligation, ProjectStatus, ProjectUser, Project,
      QuotableItemQuote, Quote, ReportFormFieldAnswer, Report, Resource,
      SectorableItem, Sector, Story, StoryIdea, UserFormFormField, UserForm,
      User, WindowsType, WorkshopAgeRange, WorkshopIdea, WorkshopLog,
      WorkshopResource, WorkshopSeriesMembership, WorkshopVariation, Workshop
    ]

    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    csv_file = Rails.root.join("tmp", "attachment_urls_#{timestamp}.csv")

    CSV.open(csv_file, "w") do |csv|
      # Header row
      csv << ["model", "record_id", "column", "attachment_url"]

      models.each do |model|
        text_columns = model.columns.select { |c| c.type == :text }.map(&:name)
        puts "Processing #{model}"

        model.find_each(start: start_id, finish: finish_id) do |record|
          text_columns.each do |column|
            next unless record[column].present?

            urls = []

            # Scan for <a href="...">
            record[column].scan(/<a\s+[^>]*href=["']([^"']+)["']/i) { |m| urls << m[0] }

            # Write each attachment URL to CSV
            urls.each do |url|
              csv << [model.name, record.id, column, url]
            end
          end
        end
      end
    end

    puts "CSV report generated at #{csv_file}"
  end
end
