namespace :resource_assets do
  desc "Fix asset types: promote gallery PDF to primary if primary is image"
  task fix_types: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    batch_size = 100

    Resource.find_in_batches(batch_size: batch_size) do |resources|
      resources.each do |r|
        ActiveRecord::Base.transaction do
          pa = r.assets.where(type: "PrimaryAsset")
          ga = r.assets.where(type: "GalleryAsset")

          primary_count = pa.joins(file_attachment: :blob).count
          gallery_count = ga.joins(file_attachment: :blob).count

          next if primary_count == 0 && gallery_count == 0

          primary_cts = pa.joins(file_attachment: :blob)
                          .pluck("active_storage_blobs.content_type")

          if primary_cts.all? { |ct| ct.start_with?("application/pdf") }
            puts "[Dry Run] Skipping Resource ##{r.id} (primary is PDF)"
            next
          end

          if primary_cts.any? { |ct| ct.start_with?("image/") }
            # Dry-run messages
            if dry_run
              puts "[Dry Run] Resource ##{r.id}: Primary images (#{pa.pluck(:id).join(',')}) → Gallery"
            else
              pa.update_all(type: "GalleryAsset")
              puts "Resource ##{r.id}: Primary images → Gallery"
            end

            # First gallery PDF
            first_pdf = ga.joins(file_attachment: :blob)
                          .where("active_storage_blobs.content_type = ?", "application/pdf")
                          .first

            if first_pdf
              if dry_run
                puts "[Dry Run] Resource ##{r.id}: Gallery PDF ##{first_pdf.id} → Primary"
              else
                first_pdf.update!(type: "PrimaryAsset")
                puts "Resource ##{r.id}: Gallery PDF ##{first_pdf.id} → Primary"
              end
            else
              puts "[Dry Run] Resource ##{r.id}: No PDF in gallery to promote"
            end
          end
        end
      rescue => e
        puts "Error processing Resource ##{r.id}: #{e.message}"
        raise e
      end
    end
  end
end
