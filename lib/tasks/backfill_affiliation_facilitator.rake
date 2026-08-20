namespace :affiliations do
  desc "Backfill affiliation STI type from the title (one-off, post-deploy)"
  task backfill_facilitator: :environment do
    # Type every existing row from its title, matching Affiliation#set_type_from_title.
    facilitators = Affiliation.where("BINARY TRIM(title) = ?", "Facilitator")
                              .update_all(type: "FacilitatorAffiliation")
    jobs = Affiliation.where("BINARY TRIM(title) <> ? OR title IS NULL", "Facilitator")
                      .update_all(type: "JobAffiliation")
    puts "Typed #{facilitators} FacilitatorAffiliation(s) and #{jobs} JobAffiliation(s)."
  end
end
