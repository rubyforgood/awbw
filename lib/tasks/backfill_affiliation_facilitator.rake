namespace :affiliations do
  desc "Backfill affiliation STI type from the title (one-off, post-deploy)"
  task backfill_facilitator: :environment do
    # Type every existing row from its title, matching Affiliation#set_type_from_title:
    # exactly "Facilitator" (trimmed, case-sensitive) is a FacilitatorAffiliation,
    # everything else a JobAffiliation. update_all is deliberate — the value is
    # computed inline, so no per-row callback is needed.
    facilitators = Affiliation.where("BINARY TRIM(title) = ?", "Facilitator")
                              .update_all(type: "FacilitatorAffiliation")
    jobs = Affiliation.where("BINARY TRIM(title) <> ? OR title IS NULL", "Facilitator")
                      .update_all(type: "JobAffiliation")
    puts "Typed #{facilitators} FacilitatorAffiliation(s) and #{jobs} JobAffiliation(s)."
  end
end
