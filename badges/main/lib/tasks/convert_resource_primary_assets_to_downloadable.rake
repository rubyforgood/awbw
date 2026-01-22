namespace :assets do
  desc "Convert all PrimaryAssets associated with Resources to DownloadableAssets"
  task convert_primary_to_downloadable: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    batch_size = ENV["BATCH_SIZE"]&.to_i || 100

    puts "#{dry_run ? '[DRY RUN] ' : ''}Starting conversion of PrimaryAssets to DownloadableAssets..."

    # Find all PrimaryAssets associated with Resources
    primary_assets = Asset.where(type: "PrimaryAsset", owner_type: "Resource")

    total_count = primary_assets.count
    puts "#{dry_run ? '[DRY RUN] ' : ''}Found #{total_count} PrimaryAssets associated with Resources"

    if total_count == 0
      puts "No PrimaryAssets found. Nothing to convert."
      return
    end

    converted_count = 0

    primary_assets.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |asset|
        resource = asset.owner

        print "#{dry_run ? '[DRY RUN] ' : ''}Resource ##{resource.id}: PrimaryAsset ##{asset.id} → DownloadableAsset"

        unless dry_run
          begin
            asset.update!(type: "DownloadableAsset")
            puts " ✓"
            converted_count += 1
          rescue => e
            puts " ✗ ERROR: #{e.message}"
          end
        else
          puts
        end
      end
    end

    puts "#{dry_run ? '[DRY RUN] ' : ''}Conversion complete. #{dry_run ? 'Would convert' : 'Converted'} #{dry_run ? total_count : converted_count} PrimaryAssets to DownloadableAssets."
  end

  desc "Convert all ThumbnailAssets associated with Resources to PrimaryAssets"
  task convert_thumbnail_to_primary: :environment do
    dry_run = ENV["DRY_RUN"] == "true"
    batch_size = ENV["BATCH_SIZE"]&.to_i || 100

    puts "#{dry_run ? '[DRY RUN] ' : ''}Starting conversion of ThumbnailAssets to PrimaryAssets..."

    # Find all ThumbnailAssets associated with Resources
    thumbnail_assets = Asset.where(type: "ThumbnailAsset", owner_type: "Resource")

    total_count = thumbnail_assets.count
    puts "#{dry_run ? '[DRY RUN] ' : ''}Found #{total_count} ThumbnailAssets associated with Resources"

    if total_count == 0
      puts "No ThumbnailAssets found. Nothing to convert."
      next
    end

    converted_count = 0

    thumbnail_assets.find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |asset|
        resource = asset.owner

        print "#{dry_run ? '[DRY RUN] ' : ''}Resource ##{resource.id}: ThumbnailAsset ##{asset.id} → PrimaryAsset"

        unless dry_run
          begin
            asset.update!(type: "PrimaryAsset")
            puts " ✓"
            converted_count += 1
          rescue => e
            puts " ✗ ERROR: #{e.message}"
          end
        else
          puts
        end
      end
    end

    puts "#{dry_run ? '[DRY RUN] ' : ''}Conversion complete. #{dry_run ? 'Would convert' : 'Converted'} #{dry_run ? total_count : converted_count} ThumbnailAssets to PrimaryAssets."
  end
end
