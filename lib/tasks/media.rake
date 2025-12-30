namespace :media do
	desc "Copy ActiveStorage attachments from Image records to Asset records (reuses blobs)"
	task copy_to_assets: :environment do
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


		Attachment.includes(file_attachment: :blob).find_each(batch_size: 100) do |image|
			processed += 1

			unless image.file.attached?
				skipped += 1
				next
			end

			asset = Asset.create!(
				owner: image.owner,
				type: "SecondaryAsset"
			)

			asset.file.attach(image.file.blob)
			created += 1

			if (processed % 500).zero?
				puts "Processed #{processed}/#{total} images…"
			end
		rescue => e
			puts "❌ Failed on Image##{image.id}: #{e.class} – #{e.message}"
		end

		puts "Attachments processed: #{processed}"
		puts "Assets created:   #{created}"
		puts "Attachments skipped:   #{skipped}"
	end


	puts "Done."

	# ----------------------------
	# Helpers
	# ----------------------------
	def map_image_type(image_type)
		{
			"MainImage"    => "PrimaryAsset",
			"GalleryImage" => "SecondaryAsset",
			"SquareImage" => "SquareAsset",
			"Images::MainImage"    => "PrimaryAsset",
			"Images::GalleryImage" => "SecondaryAsset",
			"Images::SquareImage" => "SquareAsset"
		}.fetch(image_type, "Asset")
	end
end
