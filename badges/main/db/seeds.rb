puts "Creating Users…"
admin = User.where(first_name: "Umberto", last_name: "User",
                   email: "umberto.user@example.com",
                   super_user: true)
            .first_or_create!(password: "password")
nonadmin = User.where(first_name: "Amy", last_name: "User",
                      email: "amy.user@example.com",
                      super_user: false)
               .first_or_create!(password: "password")
User.where(first_name: "Orphaned Reports", last_name: "User",
           email: "orphaned_reports@awbw.org").first_or_create!(password: "password")
user_password = Devise::Encryptor.digest(User, 'password')
User.in_batches do |batch|
  batch.update_all(encrypted_password: user_password)
end

puts "Creating WindowsTypes…"
adult_type = WindowsType.where(name: "ADULT WINDOWS", legacy_id: 1, short_name: "ADULT").first_or_create!
childrens_type = WindowsType.where(name: "CHILDREN'S WINDOWS", legacy_id: 2, short_name: "CHILDREN").first_or_create!
combined_type = WindowsType.where(name: "ADULT & CHILDREN COMBINED (FAMILY) WINDOWS",
                                  legacy_id: 3, short_name: "COMBINED").first_or_create!

puts "Creating FormBuilders…"
FormBuilder.where(name: "Adult Monthly Report", windows_type: adult_type).first_or_create!(id: 4)
FormBuilder.where(name: "Adult Workshop Log", windows_type: adult_type).first_or_create!(id: 3)
FormBuilder.where(name: "Children's Monthly Report", windows_type: childrens_type).first_or_create!(id: 2)
FormBuilder.where(name: "Children's Workshop Log", windows_type: childrens_type).first_or_create!(id: 1)
FormBuilder.where(name: "Share a Story", windows_type: combined_type).first_or_create!(id: 10)
FormBuilder.where(name: "Family Workshop Log", windows_type: combined_type).first_or_create!(id: 5)

puts "Creating ProjectStatuses…"
ProjectStatus.where(name: "Active").first_or_create!(id: 1)
ProjectStatus.where(name: "Inactive").first_or_create!(id: 2)
ProjectStatus.where(name: "Pending").first_or_create!(id: 3)
ProjectStatus.where(name: "Reinstate").first_or_create!(id: 4)
ProjectStatus.where(name: "Suspended").first_or_create!(id: 5)

puts "Creating ProjectObligations…"
ProjectObligation::OBLIGATION_TYPES.each do |obligation_type|
  ProjectObligation.where(name: obligation_type).first_or_create!
end

puts "Creating Sectors…"
Sector::SECTOR_TYPES.each do |sector_type|
  Sector.where(name: sector_type, published: true).first_or_create!
end

puts "Creating CategoryTypes/Categories…"
category_type_categories = [
  ["AgeRange", "3-5"],
  ["AgeRange", "6-12"],
  ["AgeRange", "Teen"],
  ["AgeRange", "Adult"],
  ["AgeRange", "Mixed-age groups"],
  ["AgeRange", "Family Windows"],
  # ["ArtType", "Boxes", 1],
  ["ArtType", "Clay", 11],
  ["ArtType", "Collage", 2],
  ["ArtType", "Coioring"], # fake id
  ["ArtType", "Cray-Pas (crayon, oil pastels)", 3],
  ["ArtType", "Digital Media", 21],
  ["ArtType", "Dolls", 10],
  ["ArtType", "Drawing", 17],
  ["ArtType", "Embodied Art", 20],
  ["ArtType", "Jewelry", 13],
  ["ArtType", "Journaling", 5],
  ["ArtType", "Masks", 16],
  ["ArtType", "Mixed-Media", 6],
  ["ArtType", "Painting", 7],
  ["ArtType", "Poetry/Creative Writing"], # fake id
  ["ArtType", "Puppets", 8],
  ["ArtType", "Scratch Art", 18],
  ["ArtType", "Sculpture", 9],
  ["ArtType", "Shrinky Dinks", 12],
  ["ArtType", "Touchstones"], # fake id
  ["ArtType", "Watercolor"], # fake id

  ["EmotionalTheme", "Communication"],
  # ["EmotionalTheme", "D.V.", 10],
  # ["EmotionalTheme", "Dreams and Wishes", 2],
  ["EmotionalTheme", "Discovering My Feelings", 1],
  ["EmotionalTheme", "Empathy"],
  ["EmotionalTheme", "Gratitude"],
  ["EmotionalTheme", "Grief"],
  ["EmotionalTheme", "Handling Anger", 3],
  ["EmotionalTheme", "Hopeful Future"],
  # ["EmotionalTheme", "Leaving the Shelter", 4],
  ["EmotionalTheme", "My Body", 5],
  ["EmotionalTheme", "Relationships / Boundaries", 6],
  ["EmotionalTheme", "Safety and Security", 7],
  ["EmotionalTheme", "Self-Care", 9],
  ["EmotionalTheme", "Self-Esteem", 11],
  ["EmotionalTheme", "Self-Regulation"],
  # ["EmotionalTheme", "Sexual Assault/Abuse", 13],
  ["EmotionalTheme", "Spirituality", 12],
  ["EmotionalTheme", "Transitions"],
  ["EmotionalTheme", "Who Am I?", 8],
  ["Focus", "Adults and Children Together", 6],
  ["Focus", "Collaboration and Mutuality"],
  ["Focus", "Community Engagement", 19],
  ["Focus", "Cultural Issues"],
  ["Focus", "Dating Violence for Teens", 15],
  ["Focus", "DV 101", 16],
  ["Focus", "Easy Set-up", 1],
  ["Focus", "Empowerment, Voice, and Choice"],
  # ["Focus", "Exhibit Recommended", 10],
  ["Focus", "Gender Issues"],
  ["Focus", "Good for Exhibits"],
  ["Focus", "Good for New Leaders", 3],
  ["Focus", "Good for New Participants"],
  ["Focus", "Good for One-on-One Sessions", 2],
  # ["Focus", "Good for Working with Boys", 4],
  ["Focus", "Good for Staff"],
  ["Focus", "Historical Trauma"],
  ["Focus", "Inexpensive Supplies", 5],
  # ["Focus", "Life Skills", 7],
  ["Focus", "Movement and Body Awareness", 17],
  ["Focus", "Peer Support"],
  ["Focus", "Resilience"],
  ["Focus", "Skill Building"],
  ["Focus", "Social Emotional Learning"],
  ["Focus", "Spanish Translation", 11],
  # ["Focus", "Staff Retreat", 9],
  # ["Focus", "Storytelling", 18],
  ["Focus", "Team Building", 8],
  ["Focus", "Transparency"],
  ["HolidayTheme", "Chanukah", 1],
  ["HolidayTheme", "Child Abuse Prevention Month"],
  ["HolidayTheme", "Christmas", 2],
  ["HolidayTheme", "Denim Day"],
  ["HolidayTheme", "DV Awareness Month", 9],
  ["HolidayTheme", "Easter", 3],
  ["HolidayTheme", "Father's Day", 12],
  # ["HolidayTheme", "Halloween", 4],
  ["HolidayTheme", "Independence Day", 5],
  ["HolidayTheme", "Mother's Day", 8],
  ["HolidayTheme", "New Year", 7],
  ["HolidayTheme", "Sexual Assault Awareness Month", 15],
  ["HolidayTheme", "St. Patrick's Day", 14],
  ["HolidayTheme", "Teen Dating Violence Awareness Month", 16],
  # ["HolidayTheme", "Thanksgiving", 11],
  ["HolidayTheme", "Valentine's Day", 10],
  # ["Service Population", "Child Abuse"], # now a Sector
  # ["Service Population", "Domestic Violence"], # now a Sector
  # ["Service Population", "Education/Schools"], # now a Sector
  # ["Service Population", "LGBTQIA"], # now a Sector
  # ["Service Population", "Sexual Assault"], # now a Sector
  # ["Service Population", "Substance Abuse"], # now a Sector
  # ["Service Population", "Veterans & Military"], # now a Sector
]
category_type_categories.each do |category_type_name, category_name, legacy_id|
  unless category_type_name.nil?
    metadata = CategoryType.find_or_create_by!(name: category_type_name)
    metadata.categories.find_or_create_by!(name: category_name)
  end
end
