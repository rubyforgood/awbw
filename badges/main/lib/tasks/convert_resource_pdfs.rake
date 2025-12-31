# lib/tasks/migrate_resource_pdfs.rake
require "open-uri"

namespace :resources do
  desc "Migrate legacy PDF URLs to main or gallery images"
  task migrate_pdfs: :environment do
    dry_run = ENV["DRY_RUN"] == "true"

    scope = Resource.where.not(url: [ nil, "" ]).where.not(
      kind: [ "Story", "LeaderSpotlight", "SectorImpact", "Scholarship", "Theme" ])

    puts "Found #{scope.count} resources with legacy PDF URLs"
    puts "DRY RUN: #{dry_run ? 'ON' : 'OFF'}"
    puts "-" * 70

    scope.find_each(batch_size: 25) do |resource|
      puts "→ Resource ##{resource.id} — #{resource.title}"

      begin
        uri = URI.parse(resource.url)
        filename = File.basename(uri.path.presence || "resource-#{resource.id}.pdf")

        image_class = resource.primary_asset.blank? ? PrimaryAsset : GalleryAsset

        puts "  Resource type: #{resource.kind}"
        puts "  Target image type: #{image_class.name}"
        puts "  Source URL: #{resource.url}"
        puts "  Filename: #{filename}"
        puts "  ++++++++++"

        if dry_run
          puts "  DRY RUN — no changes made"
          puts "-" * 70
          next
        end

        file = uri.open(
          read_timeout: 30,
          ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER
        )

        unless file.content_type == "application/pdf"
          raise "Expected PDF, got #{file.content_type}"
        end

        uploaded_file = ActionDispatch::Http::UploadedFile.new(
          tempfile: file,
          filename: filename,
          type: "application/pdf"
        )

        image = image_class.create!(
          owner: resource,
          file: uploaded_file
        )

        puts "  ✔ Attached as #{image.class.name}"

      rescue => e
        puts "  ✖ ERROR: #{e.class}"
        puts "    #{e.message}"
        puts "    Resource left unchanged"
      end

      puts "-" * 70
    end

    puts "Migration complete."
  end
end
