namespace :seed do
  desc "Download seed resources (PDFs, images) from external sources"
  task resources: :environment do
    require 'open-uri'
    
    puts "Downloading seed resources..."
    
    # Create directories if they don't exist
    FileUtils.mkdir_p(Rails.root.join('public', 'documents'))
    FileUtils.mkdir_p(Rails.root.join('public', 'images'))
    
    # Download Tips for Sharing Impactful Stories PDF
    pdf_path = Rails.root.join('public', 'documents', 'tips_for_sharing_impactful_stories.pdf')
    unless File.exist?(pdf_path) && File.size(pdf_path) > 0
      puts "Downloading Tips for Sharing Impactful Stories PDF..."
      begin
        URI.open('https://res.cloudinary.com/a-window-between-worlds/image/upload/v1750730476/Tips_for_Sharing_Impactful_Stories_lkuime.pdf') do |remote|
          File.open(pdf_path, 'wb') do |local|
            local.write(remote.read)
          end
        end
        puts "✓ Downloaded tips_for_sharing_impactful_stories.pdf"
      rescue => e
        puts "⚠ Warning: Failed to download PDF: #{e.message}"
        puts "  You can manually download from:"
        puts "  https://res.cloudinary.com/a-window-between-worlds/image/upload/v1750730476/Tips_for_Sharing_Impactful_Stories_lkuime.pdf"
      end
    else
      puts "✓ tips_for_sharing_impactful_stories.pdf already exists"
    end
    
    # Download info icon
    icon_path = Rails.root.join('public', 'images', 'info-icon.png')
    unless File.exist?(icon_path) && File.size(icon_path) > 0
      puts "Downloading info icon..."
      begin
        URI.open('https://stories.awbw.org/wp-content/uploads/2021/08/info-1.png') do |remote|
          File.open(icon_path, 'wb') do |local|
            local.write(remote.read)
          end
        end
        puts "✓ Downloaded info-icon.png"
      rescue => e
        puts "⚠ Warning: Failed to download icon: #{e.message}"
        puts "  You can manually download from:"
        puts "  https://stories.awbw.org/wp-content/uploads/2021/08/info-1.png"
      end
    else
      puts "✓ info-icon.png already exists"
    end
    
    puts "\nSeed resources setup complete!"
  end
end
