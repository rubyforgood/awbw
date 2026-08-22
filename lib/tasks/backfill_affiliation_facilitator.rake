namespace :affiliations do
  desc "Backfill the affiliations.facilitator flag from the title (one-off, post-deploy)"
  task backfill_facilitator: :environment do
    # Same rule as the retired .facilitators SQL scope: exactly "Facilitator",
    # trimmed, case-sensitive. update_all is deliberate — the value is computed
    # inline, so no per-row callback is needed and this stays a single bulk write.
    scope = Affiliation.where("BINARY TRIM(title) = ?", "Facilitator")
    count = scope.update_all(facilitator: true)
    puts "Backfilled facilitator: true on #{count} affiliation(s)."
  end
end
