namespace :assets do
  desc "Copy ActiveStorage Attachment, Image, MediaFile, and 'Header' records into Asset records"
  task generate: [
    :copy_images_to_assets,
    :copy_attachments_to_assets,
    :copy_media_files_to_assets,
    :assign_primary_assets,
    :ensure_one_primary_asset
  ]

  desc "Copy images or attachments to PrimaryAsset, if no PrimaryAsset exists"
  task assign_primary_assets: :environment do
    scope = Asset.where(type: "GalleryAsset").includes(:owner, file_attachment: :blob)

    puts "Scanning #{scope.count} GalleryAssets"

    scope.find_each(batch_size: 100) do |gallery_asset|
      owner = gallery_asset.owner
      next unless owner

      # Skip if owner already has a PrimaryAsset
      next if owner.primary_asset&.file&.attached?

      PrimaryAsset.transaction do
        primary = owner.build_primary_asset

        primary.file.attach(gallery_asset.file.blob)
        primary.save!

        puts "✓ Promoted GalleryAsset##{gallery_asset.id} → PrimaryAsset for #{owner.class}##{owner.id}"
      end
    rescue => e
      warn "✗ Failed for GalleryAsset##{gallery_asset.id}: #{e.message}"
    end

    puts "Done."
  end

  desc "Ensure exactly one PrimaryAsset per owner; demote extras, promote GalleryAssets if needed"
  task ensure_one_primary_asset: :environment do
    owners = Asset
               .distinct
               .pluck(:owner_type, :owner_id)
               .map { |type, id| type.constantize.find_by(id: id) }
               .compact

    puts "Processing #{owners.count} owners"

    owners.each do |owner|
      PrimaryAsset.transaction do
        primary_assets  = owner.assets.where(type: "PrimaryAsset").includes(file_attachment: :blob)
        gallery_assets  = owner.assets.where(type: "GalleryAsset").includes(file_attachment: :blob)

        # --------------------------------------------------
        # CASE 1: Multiple PrimaryAssets → keep first, demote rest
        # --------------------------------------------------
        if primary_assets.count > 1
          keeper = primary_assets.first

          primary_assets.offset(1).each do |extra|
            extra.update!(type: "GalleryAsset")
            puts "↓ Demoted PrimaryAsset##{extra.id} → GalleryAsset for #{owner.class}##{owner.id}"
          end

          next
        end

        # --------------------------------------------------
        # CASE 2: No PrimaryAsset → promote first GalleryAsset
        # --------------------------------------------------
        if primary_assets.empty? && gallery_assets.any?
          gallery = gallery_assets.first

          gallery.update!(type: "PrimaryAsset")
          puts "↑ Promoted GalleryAsset##{gallery.id} → PrimaryAsset for #{owner.class}##{owner.id}"
        end
      end
    rescue => e
      warn "✗ Failed for #{owner.class}##{owner.id}: #{e.message}"
    end

    puts "Done."
  end

  desc "Copy has_one_attached :header into associated PrimaryAsset"
  task copy_headers_to_primary_assets: :environment do
    scope = Workshop.includes(header_attachment: :blob, primary_asset: { file_attachment: :blob })

    say "Scanning #{scope.count} records"

    scope.find_each(batch_size: 100) do |record|
      next unless record.header.attached?
      next if record.primary_asset&.file&.attached?

      PrimaryAsset.transaction do
        asset = record.build_primary_asset
        asset.owner = record
        asset.file.attach(record.header.blob)
        asset.save!

        puts "✓ Copied header → PrimaryAsset for #{record.class}##{record.id}"
      end
    rescue => e
      warn "✗ Failed for #{record.class}##{record.id}: #{e.message}"
    end

    puts "Done."
  end

  desc "Copy ActiveStorage images from Image records to Asset records (reuses blobs)"
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

  desc "Copy ActiveStorage attachments from Attachment records to Asset records (reuses blobs)"
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
        type: "GalleryAsset"
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

  desc "Copy ActiveStorage media_files from MediaFile records to Asset records (reuses blobs)"
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
        type: "GalleryAsset"
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

  private

  def say(message)
    puts "\n=== #{message} ==="
  end

  # ----------------------------
  # Helpers
  # ----------------------------
  def map_image_type(image_type) # needed only for staging data - TODO - delete this method post-migration
    {
      "MainImage"            => "PrimaryAsset",
      "GalleryImage"         => "GalleryAsset",
      "RichText"             => "RichTextAsset",
      "Images::MainImage"    => "PrimaryAsset",
      "Images::GalleryImage" => "GalleryAsset",
      "Images::RichText"     => "RichTextAsset"
    }.fetch(image_type, "PrimaryAsset")
  end
end
