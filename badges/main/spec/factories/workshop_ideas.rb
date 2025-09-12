FactoryBot.define do
  # Workshop factory is defined in workshops.rb

  # Specific factory for WorkshopIdea inheriting from Workshop
  factory :workshop_idea, parent: :workshop, class: 'WorkshopIdea' do
    inactive { true } # Default scope for WorkshopIdea
    # Add specific attributes or associations for WorkshopIdea if needed
  end
end 