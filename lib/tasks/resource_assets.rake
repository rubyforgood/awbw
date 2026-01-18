# lib/tasks/resource_assets.rake
namespace :resource_assets do
  desc "Fix asset types: move primary image to thumbnail and handle gallery PDFs"
  task fix_types: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    batch_size = 100

    Resource.find_in_batches(batch_size: batch_size) do |resources|
      resources.each do |r|
        ActiveRecord::Base.transaction do
          primary = r.assets.find_by(type: "PrimaryAsset")
          gallery = r.assets.where(type: "GalleryAsset")

          # Skip if no assets
          next unless primary || gallery.exists?

          if primary
            primary_ct = primary.file.attached? ? primary.file.blob.content_type : nil

            # Skip if primary is PDF
            if primary_ct&.start_with?("application/pdf")
              puts "[Dry Run] Skipping Resource ##{r.id} (primary is PDF)" if dry_run
              next
            end

            # Handle primary image
            if primary_ct&.start_with?("image/")
              # Move primary to thumbnail
              if dry_run
                puts "[Dry Run] Resource ##{r.id}: Primary ##{primary.id} → ThumbnailAsset"
              else
                primary.update!(type: "ThumbnailAsset")
              end

              if gallery.empty?
                # Gallery empty → create new primary from the thumbnail image
                if dry_run
                  puts "[Dry Run] Resource ##{r.id}: Gallery empty, creating new PrimaryAsset from Thumbnail ##{primary.id}"
                else
                  new_primary = PrimaryAsset.create!(owner: r)
                  new_primary.file.attach(primary.file.blob) if primary.file.attached?
                end
              else
                # Promote first PDF in gallery → primary
                first_pdf = gallery.joins(file_attachment: :blob)
                                   .where("active_storage_blobs.content_type = ?", "application/pdf")
                                   .first
                if first_pdf
                  if dry_run
                    puts "[Dry Run] Resource ##{r.id}: Promoting Gallery PDF ##{first_pdf.id} → Primary"
                  else
                    first_pdf.update!(type: "PrimaryAsset")
                  end
                else
                  puts "[Dry Run] Resource ##{r.id}: No PDF in gallery to promote"
                end
              end
            end
          end
        end # transaction
      rescue => e
        puts "Error processing Resource ##{r.id}: #{e.message}"
        raise e
      end
    end # batch
  end
end
