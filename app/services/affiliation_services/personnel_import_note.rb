module AffiliationServices
  # The wording the FileMaker Personnel import leaves on an affiliation, kept in one place so
  # the importer that writes it and the affiliations index that filters on it can't drift apart.
  module PersonnelImportNote
    COMMENT_TOPIC = "FileMaker import".freeze
    SOURCE = "fm_import_personnel".freeze
    CREATE_EVENT = "create.affiliation".freeze
    END_SOURCES = {
      never_started: "their FileMaker notes, which say the program never started",
      notes: "the latest dated entry in their FileMaker notes saying they stopped",
      project_closed: "the project's close date",
      own_log: "their own last workshop log on that project",
      saved: "the day FileMaker last saved the Personnel row",
      project_log: "the project's last workshop log",
      stand_in: "December 31 of the year they started (a stand-in)"
    }.freeze
    END_SOURCE_LABELS = {
      never_started: "Never started",
      notes: "Their notes",
      project_closed: "Project closed",
      own_log: "Own last log",
      saved: "Last saved",
      project_log: "Project's last log",
      stand_in: "Dec 31 stand-in"
    }.freeze

    def self.end_phrase(source) = "from #{END_SOURCES.fetch(source)}."

    def self.end_source_in(body)
      END_SOURCES.each_key.find { |source| body.to_s.include?(end_phrase(source)) }
    end
  end
end
