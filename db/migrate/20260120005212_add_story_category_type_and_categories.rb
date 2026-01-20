class AddStoryCategoryTypeAndCategories < ActiveRecord::Migration[8.1]
  def up
    # Create the StoryCategory type if it doesn't exist
    story_category_type = CategoryType.find_or_create_by!(name: "StoryCategory")

    # List of story categories from the WordPress form
    story_categories = [
      "Advocacy (legislation, voter mobilization, etc.)",
      "Batterers Intervention (working with people who have caused harm)",
      "Child Abuse / Neglect",
      "Community Engagement",
      "Community Violence (gang violence, police violence, mass shootings etc.)",
      "Court & Legal System (including law enforcement and probation)",
      "Disability Services",
      "Domestic Violence",
      "Donor Engagement",
      "Foster Care",
      "Grief & Loss",
      "Homelessness",
      "Human Trafficking",
      "Immigration (family separation, deportation, refugees/asylees, etc.)",
      "Incarceration",
      "LGBTQIA+",
      "Mental Health (DSM, suicidal ideation, etc.)",
      "Military & Veterans",
      "Physical & Terminal Illness",
      "Schools & Universities",
      "Self-Care & Personal Growth",
      "Sexual Assault",
      "Social Justice (anti-oppression, restorative justice, systems change, etc.)",
      "Staff & Organizational Development",
      "Substance Abuse Recovery"
    ]

    # Create each category with proper ordering
    story_categories.each_with_index do |category_name, index|
      story_category_type.categories.find_or_create_by!(name: category_name) do |category|
        category.position = (index + 1) * 10
        category.published = true
      end
    end
  end

  def down
    story_category_type = CategoryType.find_by(name: "StoryCategory")
    story_category_type&.categories&.destroy_all
    story_category_type&.destroy
  end
end
