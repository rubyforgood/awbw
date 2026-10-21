# frozen_string_literal: true

# Record which portal user each FileMaker EnteredBy/ModifiedBy name means, as StaffAlias
# rows, from a staff list kept outside the repo (see StaffAliasLoader for its columns).
#
# Idempotent and safe to re-run: a name already recorded is left alone, and a name whose
# user doesn't exist yet is reported so a later run can pick it up.
#
#   bin/rails data:load_staff_aliases FILE=/path/to/staff.tsv
namespace :data do
  desc "Record FileMaker staff names → portal users as staff aliases from FILE (idempotent)."
  task load_staff_aliases: :environment do
    path = ENV["FILE"].presence
    abort "Pass the staff list: FILE=/path/to/staff.tsv" unless path && File.exist?(path)

    StaffAliasLoader.call(path)
  end
end
