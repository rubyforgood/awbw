# frozen_string_literal: true

namespace :data do
  desc "Backfill created_by_id/updated_by_id on legacy rows from the Ahoy lifecycle trail"
  task backfill_user_stamps: :environment do
    # Concrete models carrying the stamp columns. Report is the STI base for
    # MonthlyReport, so scanning it covers both (find_each yields the leaf instances,
    # so record.class.name matches the Ahoy resource_type).
    model_classes = [
      Banner, Comment, CommunityNews, ContinuingEducationRegistration, Event, Grant,
      Person, ProfessionalLicense, Report, Resource, Story, StoryIdea, User, Workshop,
      WorkshopIdea, WorkshopLog, WorkshopVariation, WorkshopVariationIdea
    ]

    model_classes.each do |klass|
      stamps = klass.column_names & %w[created_by_id updated_by_id]
      next if stamps.empty?

      scope = klass.where(stamps.map { |c| "#{c} IS NULL" }.join(" OR "))
      filled = 0

      scope.find_each do |record|
        updates = {}

        if stamps.include?("created_by_id") && record.created_by_id.nil?
          updates[:created_by_id] = stamp_user_from_ahoy(record, "create.%", :asc)
        end

        if stamps.include?("updated_by_id") && record.updated_by_id.nil?
          updates[:updated_by_id] = stamp_user_from_ahoy(record, "update.%", :desc)
        end

        updates.compact!
        next if updates.empty?

        # update_columns: write only the stamp columns, without touching updated_at or
        # re-firing the stamping / Ahoy tracking callbacks.
        record.update_columns(updates)
        filled += 1
      end

      puts "#{klass.name}: backfilled #{filled} #{"row".pluralize(filled)}"
    end
  end
end

# The user from the record's earliest create / latest update Ahoy event.
def stamp_user_from_ahoy(record, name_pattern, direction)
  Ahoy::Event
    .where(resource_type: record.class.name, resource_id: record.id)
    .where.not(user_id: nil)
    .where("name LIKE ?", name_pattern)
    .order(time: direction)
    .limit(1)
    .pick(:user_id)
end
