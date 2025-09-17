admin_password = Devise::Encryptor.digest(Admin, 'password')
Admin.update_all(encrypted_password: admin_password)

user_password = Devise::Encryptor.digest(User, 'password')
User.in_batches do |batch|
  batch.update_all(encrypted_password: user_password)
end

Admin.create!(first_name: "Amy", last_name: "Admin", email: "amy.admin@example.com", password: "password")
User.create!(first_name: "Umberto", last_name: "User", email: "umberto.user@example.com", password: "password")

adult_type = WindowsType.where(name: "ADULT WORKSHOP").first_or_create!
childrens_type = WindowsType.where(name: "CHILDREN WORKSHOP").first_or_create!
combined_type = WindowsType.where(name: "ADULT & CHILDREN COMBINED (FAMILY)").first_or_create!

AgeRange.find_or_create_by!(name: '3-5', windows_type: childrens_type)
AgeRange.find_or_create_by!(name: '6-12', windows_type: childrens_type)
AgeRange.find_or_create_by!(name: 'Teen', windows_type: childrens_type)
AgeRange.find_or_create_by!(name: 'Adult', windows_type: adult_type)
AgeRange.find_or_create_by!(name: 'Mixed-age groups', windows_type: combined_type)
AgeRange.find_or_create_by!(name: 'Family Windows', windows_type: combined_type)

dataset = [
  ["AgeRange", "3-5"],
  ["AgeRange", "6-12"],
  ["AgeRange", "Teen"],
  ["AgeRange", "Adult"],
  ["AgeRange", "Mixed-age groups"],
  ["AgeRange", "Family Windows"],
  ["ArtType", "Clay"],
  ["ArtType", "Collage"],
  ["ArtType", "Coioring"],
  ["ArtType", "Cray-Pas (crayon, oil pastels)"],
  ["ArtType", "Digital Media"],
  ["ArtType", "Dolls"],
  ["ArtType", "Drawing"],
  ["ArtType", "Embodied Art"],
  ["ArtType", "Jewelry"],
  ["ArtType", "Journaling"],
  ["ArtType", "Masks"],
  ["ArtType", "Mixed-Media"],
  ["ArtType", "Painting"],
  ["ArtType", "Poetry/Creative Writing"],
  ["ArtType", "Puppets"],
  ["ArtType", "Scratch Art"],
  ["ArtType", "Sculpture"],
  ["ArtType", "Shrinky Dinks"],
  ["ArtType", "Touchstones"],
  ["ArtType", "Watercolor"],
  ["EmotionalTheme", "Communication"],
  ["EmotionalTheme", "Discovering My Feelings"],
  ["EmotionalTheme", "Empathy"],
  ["EmotionalTheme", "Gratitude"],
  ["EmotionalTheme", "Grief"],
  ["EmotionalTheme", "Handling Anger"],
  ["EmotionalTheme", "Hopeful Future"],
  ["EmotionalTheme", "My Body"],
  ["EmotionalTheme", "Relationships / Boundaries"],
  ["EmotionalTheme", "Safety and Security"],
  ["EmotionalTheme", "Self-Care"],
  ["EmotionalTheme", "Self-Esteem"],
  ["EmotionalTheme", "Self-Regulation"],
  ["EmotionalTheme", "Spirituality"],
  ["EmotionalTheme", "Transitions"],
  ["EmotionalTheme", "Who Am I?"],
  ["Focus", "Adults and Children Together"],
  ["Focus", "Collaboration and Mutuality"],
  ["Focus", "Community Engagement"],
  ["Focus", "Cultural Issues"],
  ["Focus", "Dating Violence for Teens"],
  ["Focus", "DV 101"],
  ["Focus", "Easy Set-up"],
  ["Focus", "Empowerment, Voice, and Choice"],
  ["Focus", "Gender Issues"],
  ["Focus", "Good for Exhibits"],
  ["Focus", "Good for New Leaders"],
  ["Focus", "Good for New Participants"],
  ["Focus", "Good for One-on-One Sessions"],
  ["Focus", "Good for Staff"],
  ["Focus", "Historical Trauma"],
  ["Focus", "Inexpensive Supplies"],
  ["Focus", "Movement and Body Awareness"],
  ["Focus", "Peer Support"],
  ["Focus", "Resilience"],
  ["Focus", "Skill Building"],
  ["Focus", "Social Emotional Learning"],
  ["Focus", "Spanish Translation"],
  ["Focus", "Team Building"],
  ["Focus", "Transparency"],
  ["HolidayTheme", "Chanukah"],
  ["HolidayTheme", "Child Abuse Prevention Month"],
  ["HolidayTheme", "Christmas"],
  ["HolidayTheme", "Denim Day"],
  ["HolidayTheme", "DV Awareness Month"],
  ["HolidayTheme", "Easter"],
  ["HolidayTheme", "Father's Day"],
  ["HolidayTheme", "Independence Day"],
  ["HolidayTheme", "Mother's Day"],
  ["HolidayTheme", "New Year"],
  ["HolidayTheme", "Sexual Assault Awareness Month"],
  ["HolidayTheme", "St. Patrick's Day"],
  ["HolidayTheme", "Teen Dating Violence Awareness Month"],
  ["HolidayTheme", "Valentine's Day"],
  ["Service Population", "Child Abuse"],
  ["Service Population", "Domestic Violence"],
  ["Service Population", "Education/Schools"],
  ["Service Population", "LGBTQIA"],
  ["Service Population", "Sexual Assault"],
  ["Service Population", "Substance Abuse"],
  ["Service Population", "Veterans & Military"],
]

dataset.each do |metadata_name, category_name|
  unless metadata_name.nil?
    metadata = Metadata.find_or_create_by!(name: metadata_name)
    metadata.categories.find_or_create_by!(name: category_name)
  end
end
