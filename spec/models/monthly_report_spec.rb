require 'rails_helper'

RSpec.describe MonthlyReport do
  it "uses the reports table" do
    expect(MonthlyReport.table_name).to eq("reports")
  end

  it "sets type to 'MonthlyReport' on create" do
    report = create(:monthly_report)
    expect(report.type).to eq("MonthlyReport")
  end

  it "default-scopes queries to type='MonthlyReport'" do
    create(:monthly_report)
    expect(MonthlyReport.all.pluck(:type).uniq).to eq([ "MonthlyReport" ])
  end
end
