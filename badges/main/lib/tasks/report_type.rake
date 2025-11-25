namespace :report_type do
  desc "Change report type from Report to ReportStory"
  task update: :environment do
    Report.where(type: "Story").update_all(type: "ReportStory")
  end
end
