# frozen_string_literal: true

# Record what each legacy word for a sector or age group resolves to, as TagAlias rows,
# without running the full db:seed. The tables are ADR-0007; the rows are what an import
# looks a term up in, and what a reader checks to see what a tag used to be called in
# FileMaker, the older forms, Story Share or the portal's earlier sector list.
#
# Idempotent and safe to re-run: a term already recorded for a tag is left alone, so an
# alias an admin added by hand survives. Run after the sectors and age ranges are seeded —
# a term whose tag doesn't exist yet is reported, not created.
#
#   bin/rails data:seed_tag_aliases
namespace :data do
  desc "Record the legacy sector and age-group terms (ADR-0007) as tag aliases (idempotent)."
  task seed_tag_aliases: :environment do
    TagAliasSeeder.call
  end
end
