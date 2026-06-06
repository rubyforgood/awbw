# Bookmark seeds (dev-only) - run on their own via `rake db:seed:bookmarks`, or as part
# of `rake db:seed:dev`. Bookmarks the first couple of records of each bookmarkable type
# for Amy and Aisha, so it is most useful after the other content seeds have run.

puts "Creating Bookmarks for seed users…"
amy = User.find_by(email: "amy.user@example.com")
aisha = User.find_by(email: "aisha.user@example.com")

if amy && aisha
  excluded_person_ids = [ amy.person_id, aisha.person_id ].compact

  # Two records per bookmarkable type (where available)
  pairs = {
    "CommunityNews"        => CommunityNews.order(:id).limit(2).to_a,
    "Event"                => Event.order(:id).limit(2).to_a,
    "Organization"         => Organization.order(:id).limit(2).to_a,
    "Person"               => Person.where.not(id: excluded_person_ids).order(:id).limit(2).to_a,
    "Report"               => Report.where.not(type: "WorkshopLog").order(:id).limit(2).to_a,
    "Resource"             => Resource.order(:id).limit(2).to_a,
    "Story"                => Story.order(:id).limit(2).to_a,
    "StoryIdea"            => StoryIdea.order(:id).limit(2).to_a,
    "VideoRecording"       => VideoRecording.order(:id).limit(2).to_a,
    "Workshop"             => Workshop.order(:id).limit(2).to_a,
    "WorkshopIdea"         => WorkshopIdea.order(:id).limit(2).to_a,
    "WorkshopLog"          => WorkshopLog.order(:id).limit(2).to_a,
    "WorkshopVariation"    => WorkshopVariation.order(:id).limit(2).to_a,
    "WorkshopVariationIdea" => WorkshopVariationIdea.order(:id).limit(2).to_a
  }.reject { |_, v| v.empty? }

  # 3 types are shared between Amy and Aisha for tally testing
  shared_types = pairs.keys.first(3)

  pairs.each do |type, records|
    if shared_types.include?(type)
      # Both users bookmark the first record
      [ amy, aisha ].each { |u| u.bookmarks.find_or_create_by!(bookmarkable: records.first) }
    else
      # Each user gets a different record (Aisha falls back to first if only one exists)
      amy.bookmarks.find_or_create_by!(bookmarkable: records.first)
      aisha.bookmarks.find_or_create_by!(bookmarkable: records.last)
    end
  end

  puts "  Created #{amy.bookmarks.count} bookmarks for Amy, #{aisha.bookmarks.count} for Aisha"
  shared = amy.bookmarks.pluck(:bookmarkable_type, :bookmarkable_id) &
           aisha.bookmarks.pluck(:bookmarkable_type, :bookmarkable_id)
  puts "  #{shared.size} bookmarks shared between both users"
end
