require 'rails_helper'

RSpec.describe MonthlyReport do
  it_behaves_like "author_creditable", factory: :monthly_report, org_credited: false, credits_creator_legacy: true

  describe "#author_credit" do
    it "credits an unauthored report to the creator's person by name" do
      creator = create(:user, :with_person)
      report = create(:monthly_report, author: nil, created_by: creator)
      expect(report.author_credit).to eq(creator.person.name)
    end

    it "reads Anonymous when there is no author and no creator person" do
      report = create(:monthly_report, author: nil, created_by: create(:user, person: nil))
      expect(report.author_credit).to eq("Anonymous")
    end

    it "reads Anonymous when the creator's person opted out of being credited" do
      creator = create(:user, person: create(:person, :anonymous_contributions))
      report = create(:monthly_report, author: nil, created_by: creator)
      expect(report.author_credit).to eq("Anonymous")
    end
  end

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
