# frozen_string_literal: true

require "set"

# Applies the 2026 sector taxonomy to existing data: a sequence of renames and
# merges that fold legacy Forms / FileMaker / portal sector names into the
# canonical Sector::SECTOR_TYPES set, plus the handful of brand-new tags and the
# Story Share → Portal source aliases.
#
# Mechanics:
#   * Merges reuse ModelDeduper#merge, so all polymorphic taggings
#     (SectorableItem records on Person, Organization, Workshop, Report, …) are
#     moved onto the surviving sector before the duplicate is destroyed.
#   * Every operation is idempotent and tolerant of missing legacy records — a
#     source name that isn't present in this database is simply skipped, so the
#     task is safe to re-run and safe across environments with different data.
#   * Order matters: the operations run in the exact sequence given in the
#     taxonomy spreadsheet, because several are chains (e.g. A→B→C→canonical)
#     where each step depends on the previous one having landed.
#
# Dry-run by default. Set DRY_RUN=false to write changes.
#
#   bin/rails data:migrate_sectors              # preview
#   DRY_RUN=false bin/rails data:migrate_sectors # execute
#
# NOTE on dry runs: because renames aren't persisted in a dry run, a later step
# in a rename→merge chain may report "source not present". That's expected — the
# live run resolves each chain in order.
namespace :data do
  desc "Apply the 2026 sector taxonomy (sequential renames/merges + new tags). Idempotent. DRY_RUN=false to execute."
  task migrate_sectors: :environment do
    logger = Logger.new($stdout)
    logger.formatter = ->(_severity, _time, _progname, msg) { "#{msg}\n" }

    dry_run = ENV["DRY_RUN"] != "false"
    deduper = ModelDeduper.new(model_class: Sector, dry_run: dry_run, logger: logger)

    stats = Hash.new(0)

    find_sector = lambda do |name|
      Sector.where("LOWER(TRIM(name)) = ?", name.to_s.strip.downcase).first
    end

    # Fold `from`'s data under the canonical name `to`, in place:
    #   * source missing                 → skip (legacy name absent in this DB)
    #   * target missing                 → rename the source to `to`
    #   * source and target same record  → normalize the stored name only
    #   * both present, distinct records → merge source into target (moves taggings)
    consolidate = lambda do |from, to|
      source = find_sector.call(from)
      unless source
        logger.info "SKIP    #{from.inspect} → #{to.inspect} (source not present)"
        stats[:skipped] += 1
        next
      end

      target = find_sector.call(to)

      if target.nil?
        logger.info "RENAME  #{source.name.inspect} → #{to.inspect}"
        source.update!(name: to) unless dry_run
        stats[:renamed] += 1
      elsif target.id == source.id
        if source.name == to
          logger.info "OK      #{to.inspect} already canonical"
        else
          logger.info "TRIM    #{source.name.inspect} → #{to.inspect}"
          source.update!(name: to) unless dry_run
          stats[:renamed] += 1
        end
      else
        logger.info "MERGE   #{source.name.inspect} (##{source.id}) → #{target.name.inspect} (##{target.id})"
        deduper.merge(target, source)
        stats[:merged] += 1
      end
    end

    ensure_sector = lambda do |name|
      existing = find_sector.call(name)
      if existing
        logger.info "EXISTS  #{name.inspect} (##{existing.id})"
        existing.update!(published: true) unless dry_run || existing.published?
        stats[:existing] += 1
      else
        logger.info "ADD     #{name.inspect}"
        Sector.create!(name: name, published: true) unless dry_run
        stats[:added] += 1
      end
    end

    run_op = lambda do |op|
      case op[0]
      when :rename, :merge then consolidate.call(op[1], op[2])
      when :add, :no_change then ensure_sector.call(op[1])
      end
    end

    # --- Forms / FileMaker / existing portal data → new sector tags ---------
    # Sequential, in spreadsheet order. Renames whose target already exists as a
    # canonical sector become merges (the canonical record survives, taggings move).
    portal_ops = [
      [ :rename, "People Who Do Harm/Batterers", "Batterers Intervention" ],
      [ :rename, "Child abuse", "Child Abuse/Neglect" ],
      [ :rename, "Climate/Environmental Trauma", "Climate/Environmental" ],
      [ :add, "Community Engagement" ],
      [ :rename, "Community oppression/violence", "Community Violence" ],
      [ :merge, "Victims of Crime", "Law Enforcement/Court" ],
      [ :merge, "Law Enforcement/Court", "Criminal/Legal" ],
      [ :rename, "Criminal/legal", "Court/Legal System" ],
      [ :rename, "Disability", "Disability Services" ],
      [ :no_change, "Domestic Violence" ],
      [ :merge, "Education/schools", "Student" ],
      [ :merge, "Student", "Student-Related Stress" ],
      [ :merge, "Student-Related Stress", "Educational Setting" ],
      [ :merge, "Educational Setting", "Student Services" ],
      [ :rename, "Student Services", "Education" ],
      [ :rename, "Foster Care", "Foster Care/Adoption" ],
      [ :add, "Fundraising/Donor Engagement" ],
      [ :no_change, "Grief/Loss" ],
      [ :merge, "Pandemic-Related Stress", "Illness" ],
      [ :merge, "Illness", "Hospitals" ],
      [ :rename, "Hospitals", "Health/Medical" ],
      [ :no_change, "Homelessness" ],
      [ :no_change, "Human Trafficking" ],
      [ :no_change, "Immigration" ],
      [ :merge, "Prisons/Jails", "Incarceration" ],
      [ :no_change, "Indigenous/Tribal Nation" ],
      [ :merge, "Oppression Against LGBTQIA+", "LGBTQIA+" ],
      [ :merge, "Suicidality", "Mental Health Needs" ],
      [ :merge, "Mental Health Needs", "Clinical Setting" ],
      [ :merge, "Clinical Setting", "Mental Health" ],
      [ :merge, "Veterans & military", "Military/Veteran" ],
      [ :rename, "Military/Veteran", "Military/Veterans" ],
      [ :rename, "Private Practice", "Private Practice/Sole Proprietor" ],
      [ :rename, "Racism & Marginalization", "Racial/Social Justice" ],
      [ :merge, "Religious Trauma", "Faith-Based Setting" ],
      [ :rename, "Faith-Based Setting", "Religious/Faith Based" ],
      [ :rename, "Reproductive", "Reproductive Services" ],
      [ :no_change, "Restorative/Transformative Justice" ],
      [ :add, "Self-Care/Personal Growth" ],
      [ :no_change, "Sexual Assault" ],
      [ :merge, "Secondary/Vicarious Trauma", "With Staff" ],
      [ :merge, "With Staff", "Staff & organizational development" ],
      [ :rename, "Staff & organizational development", "Staff/Organizational Development" ],
      [ :merge, "Substance use", "Substance Abuse" ],
      [ :rename, "Substance Abuse", "Substance Use/Recovery" ],
      # Spreadsheet reads "Sytems/Policy Change" — corrected to the canonical spelling.
      [ :add, "Systems/Policy Change" ]
    ]

    # --- Story Share → Portal migration aliases ----------------------------
    # Additional legacy source names that fold into the canonical set. Identity
    # rows are harmless no-ops; the rest move taggings onto the canonical sector.
    story_share_ops = [
      [ :merge, "Batterers Intervention", "Batterers Intervention" ],
      [ :merge, "Child Abuse / Neglect", "Child Abuse/Neglect" ],
      [ :merge, "Community Engagement", "Community Engagement" ],
      [ :merge, "Community Violence", "Community Violence" ],
      [ :merge, "Court & Legal System", "Court/Legal System" ],
      [ :merge, "Disability Services", "Disability Services" ],
      [ :merge, "Domestic Violence", "Domestic Violence" ],
      [ :merge, "Schools & Universities", "Education" ],
      [ :merge, "Foster Care", "Foster Care/Adoption" ],
      [ :merge, "Donor Engagement", "Fundraising/Donor Engagement" ],
      [ :merge, "Grief & Loss", "Grief/Loss" ],
      [ :merge, "Physical & Terminal Illness", "Health/Medical" ],
      [ :merge, "Homelessness", "Homelessness" ],
      [ :merge, "Human Trafficking", "Human Trafficking" ],
      [ :merge, "Immigration", "Immigration" ],
      [ :merge, "Incarceration", "Incarceration" ],
      [ :merge, "LGBTQIA+", "LGBTQIA+" ],
      [ :merge, "Mental Health", "Mental Health" ],
      [ :merge, "Military & Veterans", "Military/Veterans" ],
      [ :merge, "Social Justice", "Racial/Social Justice" ],
      [ :merge, "Self-Care & Personal Growth", "Self-Care/Personal Growth" ],
      [ :merge, "Sexual Assault", "Sexual Assault" ],
      [ :merge, "Staff & Organizational Development", "Staff/Organizational Development" ],
      [ :merge, "Substance Abuse Recovery", "Substance Use/Recovery" ],
      # Spreadsheet reads "Sytems/Policy Change" — corrected to the canonical spelling.
      [ :merge, "Advocacy", "Systems/Policy Change" ]
    ]

    runner = lambda do
      logger.info "=== Forms / FileMaker / portal taxonomy (sequential) ==="
      portal_ops.each { |op| run_op.call(op) }
      logger.info ""
      logger.info "=== Story Share → portal aliases ==="
      story_share_ops.each { |op| run_op.call(op) }
    end

    logger.info dry_run ? "DRY RUN — no changes written. Set DRY_RUN=false to execute." : "EXECUTING — changes are being written."
    logger.info ""

    if dry_run
      runner.call
    else
      ActiveRecord::Base.transaction { runner.call }
    end

    logger.info ""
    logger.info "Summary: merged=#{stats[:merged]} renamed=#{stats[:renamed]} added=#{stats[:added]} " \
                "existing=#{stats[:existing]} skipped=#{stats[:skipped]}"

    # Sanity check: flag any still-published sector outside the expected final set.
    expected = (Sector::SECTOR_TYPES + [ "Community Engagement" ]).map { |n| n.strip.downcase }.to_set
    stray = Sector.where(published: true).reject { |s| expected.include?(s.name.strip.downcase) }
    if stray.any?
      logger.info ""
      logger.info "NOTE: #{stray.size} published sector(s) not in the expected final taxonomy:"
      stray.each { |s| logger.info "  - #{s.name.inspect} (##{s.id})" }
    end
  end
end
