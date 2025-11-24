namespace :report_type_update do
  desc "Change report type from Report to ReportStory"
  task report_story: :environment do
    Report.where(type: "Story").update_all(type: "ReportStory")
  end
end
