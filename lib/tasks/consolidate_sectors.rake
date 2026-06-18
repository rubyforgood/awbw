# frozen_string_literal: true

# Migrates sector TAGGINGS from the legacy service-area names onto the canonical
# SECTOR_TYPES list. PR #1703 already refreshed SECTOR_TYPES, seeded descriptions,
# and made seeds create the new names while *unpublishing* (not destroying) the
# old ones — but it deliberately did not move taggings, so every existing
# workshop/story/etc. tagging is stranded on a now-unpublished legacy sector while
# the new published sectors are empty. This task closes that gap.
#
# It is deploy-order-agnostic by design:
#   - Run before #1703 seeds (DB still on the old names): legacy names are renamed
#     in place, preserving taggings, and Student is merged into Education.
#   - Run after #1703 seeds (new names already exist): each rename hits the
#     collision check and falls back to a merge, re-pointing taggings onto the
#     seeded published record and destroying the empty legacy one.
namespace :data do
  desc "Migrate sector taggings from legacy names onto the canonical SECTOR_TYPES (rename in place or merge via ModelDeduper). DRY_RUN=false to apply."
  task consolidate_sectors: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"

    # Current name => new name. Renames are done in place with update!, which
    # preserves every tagging because sectorable_items reference sector_id, not
    # the name string.
    renames = {
      "Child Abuse" => "Child Abuse/Neglect",
      "Community Oppression/Violence" => "Community Violence",
      "Criminal/Legal" => "Court/Legal System",
      "Disability" => "Disability Services",
      "Education/Schools" => "Education",
      "Homeless" => "Homelessness",
      "Reproductive" => "Reproductive Services",
      "Substance Use" => "Substance Use/Recovery",
      "Veterans & Military" => "Military/Veterans"
    }

    # [ source_to_delete, target_to_keep ]. ModelDeduper re-points all taggings
    # from the source onto the target, then destroys the source. Runs after the
    # renames, so the target ("Education") already exists by this point.
    merges = [
      [ "Student", "Education" ]
    ]

    # Brand-new sectors with no current equivalent. Created published to match
    # the seed behavior in db/seeds.rb.
    new_sectors = [
      "Batterers Intervention",
      "Climate/Environmental",
      "Fundraising/Donor Engagement",
      "Grief/Loss",
      "Health/Medical",
      "Private Practice/Sole Proprietor",
      "Racial/Social Justice",
      "Religious/Faith Based",
      "Self-Care/Personal Growth",
      "Staff/Organizational Development",
      "Systems/Policy Change"
    ]

    # "Other" is intentionally left untouched — it has special handling in the
    # model (OTHER_SECTOR_NAME, the excluding_other scope) and is not part of
    # the proposed list.

    find_by_name = ->(name) { name.present? ? Sector.where("LOWER(name) = LOWER(?)", name).first : nil }

    puts "=" * 80
    puts "Sector consolidation  (DRY_RUN=#{dry_run})"
    puts "=" * 80

    renamed = 0
    merged = 0
    created = 0
    skipped = []

    # --- 1. Renames -------------------------------------------------------
    puts "\nRenaming sectors…"
    renames.each do |from, to|
      source = find_by_name.call(from)
      unless source
        skipped << "rename #{from.inspect} -> #{to.inspect}: source not found (already renamed?)"
        next
      end

      existing_target = find_by_name.call(to)
      if existing_target && existing_target.id != source.id
        # The target name is already taken by a different record, so an in-place
        # rename would violate the uniqueness validation. Fall back to a merge.
        puts "  COLLISION #{from.inspect} -> #{to.inspect}: target ##{existing_target.id} exists, merging instead"
        merges << [ from, to ]
        next
      end

      puts "  #{from.inspect} -> #{to.inspect} (sector ##{source.id})"
      source.update!(name: to) unless dry_run
      renamed += 1
    end

    # --- 2. Merges --------------------------------------------------------
    puts "\nMerging sectors…"
    deduper = ModelDeduper.new(model_class: Sector, dry_run: dry_run)
    merges.each do |source_name, target_name|
      source = find_by_name.call(source_name)
      target = find_by_name.call(target_name)
      # In a dry run the prerequisite rename hasn't been persisted, so resolve
      # the target back through its pre-rename name to preview accurately.
      target ||= find_by_name.call(renames.key(target_name))

      unless source
        skipped << "merge #{source_name.inspect} -> #{target_name.inspect}: source not found"
        next
      end
      unless target
        skipped << "merge #{source_name.inspect} -> #{target_name.inspect}: target not found"
        next
      end

      puts "  #{source_name.inspect} (##{source.id}) -> #{target_name.inspect} (##{target.id})"
      deduper.merge(target, source)
      merged += 1
    end

    # --- 3. New sectors ---------------------------------------------------
    puts "\nAdding new sectors…"
    new_sectors.each do |name|
      if find_by_name.call(name)
        skipped << "create #{name.inspect}: already exists"
        next
      end

      puts "  + #{name.inspect}"
      Sector.create!(name: name, published: true) unless dry_run
      created += 1
    end

    # --- Summary ----------------------------------------------------------
    puts "\n#{'=' * 80}"
    puts "Renamed: #{renamed}  Merged: #{merged}  Created: #{created}"
    if skipped.any?
      puts "\nSkipped (#{skipped.size}):"
      skipped.each { |s| puts "  - #{s}" }
    end

    if dry_run
      puts "\nDRY RUN — nothing was written. Re-run with DRY_RUN=false to apply."
    else
      puts "\nResulting sectors (#{Sector.count}):"
      Sector.order(:name).pluck(:name).each { |n| puts "  - #{n}" }
    end
    puts "=" * 80
  end
end
