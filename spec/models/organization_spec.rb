require 'rails_helper'

RSpec.describe Organization do
  describe 'inheritance' do
    it 'inherits from Project' do
      expect(Organization.superclass).to eq(Project)
    end

    it 'uses the projects table' do
      expect(Organization.table_name).to eq('projects')
    end
  end

  describe '#annual_evaluations_for_year' do
    let(:organization) { create(:project) }
    let(:user) { create(:user) }
    let(:form_builder) { create(:form_builder, name: "Annual Evaluation") }
    let(:form) { create(:form, owner: form_builder) }

    before do
      create(:project_user, project: organization, user: user)
    end

    it 'returns empty relation when year is not provided' do
      expect(organization.annual_evaluations_for_year(nil)).to eq(Report.none)
    end

    it 'returns reports for the specified year' do
      report_2025 = create(:report, user: user, created_at: Date.new(2025, 6, 15))
      report_2024 = create(:report, user: user, created_at: Date.new(2024, 6, 15))

      # Mock the form_builder association
      allow(Report).to receive(:joins).and_return(Report.where(id: [ report_2025.id, report_2024.id ]))

      results = organization.annual_evaluations_for_year(2025)
      expect(results).to include(report_2025)
      expect(results).not_to include(report_2024)
    end
  end

  describe '#aggregated_annual_evaluation_responses' do
    let(:organization) { create(:project) }
    let(:user) { create(:user) }

    before do
      create(:project_user, project: organization, user: user)
    end

    it 'returns empty hash when no evaluations exist' do
      allow(organization).to receive(:annual_evaluations_for_year).and_return(Report.none)
      expect(organization.aggregated_annual_evaluation_responses(2025)).to eq({})
    end

    it 'returns empty hash when form builder does not exist' do
      allow(organization).to receive(:annual_evaluations_for_year).and_return(Report.all)
      allow(FormBuilder).to receive(:find_by).with(name: "Annual Evaluation").and_return(nil)
      expect(organization.aggregated_annual_evaluation_responses(2025)).to eq({})
    end

    it 'groups responses by form field' do
      form_builder = create(:form_builder, name: "Annual Evaluation")
      form = create(:form, owner: form_builder)
      field = create(:form_field, form: form, question: "Test question", status: :active)
      report = create(:report, user: user)

      allow(organization).to receive(:annual_evaluations_for_year).and_return(Report.where(id: report.id))

      result = organization.aggregated_annual_evaluation_responses(2025)
      expect(result).to be_an(Array)
      expect(result.first).to have_key(:form_field)
      expect(result.first).to have_key(:responses)
    end
  end
end
