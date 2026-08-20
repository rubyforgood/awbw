namespace :import do
  desc "Import stories from a WordPress Posts Export CSV. " \
       "Usage: rake 'import:stories[path/to/export.csv,importer@awbw.org]' " \
       "(append ,dry to validate without writing)"
  task :stories, [ :path, :user_email, :dry ] => :environment do |_task, args|
    path = args[:path]
    abort "Provide a CSV path: rake 'import:stories[path,user_email]'" if path.blank?
    abort "CSV not found at #{path}" unless File.exist?(path)

    user =
      if args[:user_email].present?
        User.find_by!(email: args[:user_email])
      else
        abort "Provide the importing user's email: rake 'import:stories[path,user_email]'"
      end

    dry_run = args[:dry].to_s.downcase.in?(%w[dry dry_run true])

    puts "Importing #{path}"
    puts "Importing as #{user.email} (id=#{user.id})"
    puts "DRY RUN — nothing will be written" if dry_run

    result = StoryImporter.new(csv_path: path, import_user: user, dry_run: dry_run).call

    puts "\n#{result.summary}"

    if result.skipped.any?
      puts "\nSkipped rows:"
      result.skipped.each { |line| puts "  - #{line}" }
    end

    if result.warnings.any?
      puts "\nWarnings (#{result.warnings.size}) — unmapped fields / loose matches:"
      result.warnings.first(50).each { |line| puts "  - #{line}" }
      puts "  …and #{result.warnings.size - 50} more" if result.warnings.size > 50
    end
  end
end
