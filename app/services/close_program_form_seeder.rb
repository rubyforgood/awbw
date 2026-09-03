# Creates the standalone "Close Program" agreement form (Form role
# close_program) from the form-builder presets. A facilitator/organization fills
# it to tell us their AWBW program is ending; processing the submission
# end-dates their affiliations at the named organization (see
# AffiliationServices::CloseProgram).
#
# Idempotent on form name, so it's safe to run repeatedly — in db/seeds and as
# the `data:seed_close_program_form` task for prod. Built once, then left for
# staff to give a slug and publish in the form builder. Returns the name it
# created, or nil when it already existed.
class CloseProgramFormSeeder
  NAME = "Close Program".freeze
  SECTIONS = %i[person_identifier close_program].freeze

  def self.call
    new.call
  end

  def call
    return if Form.exists?(name: NAME)

    FormBuilderService.new(name: NAME, sections: SECTIONS, role: "close_program").call
    NAME
  end
end
