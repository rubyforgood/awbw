namespace :assets do
  desc "Copy ActiveStorage attachments from Image records to Asset records (reuses blobs)"
  task copy_images_to_assets: :environment do
    puts "Starting Image → Asset ActiveStorage copy…"

    total = Image.count
    processed = 0
    skipped = 0
    created = 0

    Image.includes(file_attachment: :blob).find_each(batch_size: 100) do |image|
      processed += 1

      unless image.file.attached?
        skipped += 1
        next
      end

      asset = Asset.create!(
        owner: image.owner,
        type: map_image_type(image.type)
      )

      asset.file.attach(image.file.blob)
      created += 1

      if (processed % 500).zero?
        puts "Processed #{processed}/#{total} images…"
      end
    rescue => e
      puts "❌ Failed on Image##{image.id}: #{e.class} – #{e.message}"
    end
    puts "Images processed: #{processed}"
    puts "Assets created:   #{created}"
    puts "Images skipped:   #{skipped}"

    puts "Done."
  end

  task copy_attachments_to_assets: :environment do
    puts "Starting Attachment → Asset ActiveStorage copy…"

    total = Attachment.count
    processed = 0
    skipped = 0
    created = 0

    Attachment.includes(file_attachment: :blob).find_each(batch_size: 100) do |attachment|
      processed += 1

      unless attachment.file.attached?
        skipped += 1
        next
      end

      asset = Asset.create!(
        owner: attachment.owner,
        type: "SecondaryAsset"
      )

      asset.file.attach(attachment.file.blob)
      created += 1

      if (processed % 500).zero?
        puts "Processed #{processed}/#{total} attachments…"
      end
    rescue => e
      puts "❌ Failed on Attachment##{attachment.id}: #{e.class} – #{e.message}"
    end

    puts "Attachments processed: #{processed}"
    puts "Assets created:   #{created}"
    puts "Attachments skipped:   #{skipped}"

    puts "Done."
  end


  task copy_media_files_to_assets: :environment do
    puts "Starting MediaFile → Asset ActiveStorage copy…"

    total = MediaFile.count
    processed = 0
    skipped = 0
    created = 0

    MediaFile.includes(file_attachment: :blob).find_each(batch_size: 100) do |media_file|
      processed += 1

      unless media_file.file.attached?
        skipped += 1
        next
      end

      if media_file.workshop_log_id
        owner = media_file.workshop_log
      elsif media_file.report_id
        owner = media_file.report
      end

      asset = Asset.create!(
        owner: owner,
        type: "SecondaryAsset"
      )

      asset.file.attach(media_file.file.blob)
      created += 1

      if (processed % 500).zero?
        puts "Processed #{processed}/#{total} media_files…"
      end
    rescue => e
      puts "❌ Failed on MediaFile##{media_file.id}: #{e.class} – #{e.message}"
    end

    puts "MediaFiles processed: #{processed}"
    puts "Assets created:   #{created}"
    puts "MediaFiles skipped:   #{skipped}"

    puts "Done."
  end

  # ----------------------------
  # Helpers
  # ----------------------------
  def map_image_type(image_type)
    {
      "MainImage"            => "PrimaryAsset",
      "GalleryImage"         => "SecondaryAsset",
      "SquareImage"          => "SquareAsset",
      "Square"               => "SquareAsset",
      "RichText"             => "RichTextAsset",
      "Images::MainImage"    => "PrimaryAsset",
      "Images::GalleryImage" => "SecondaryAsset",
      "Images::SquareImage"  => "SquareAsset",
      "Images::RichText"     => "RichTextAsset"
    }.fetch(image_type, "Asset")
  end
end
