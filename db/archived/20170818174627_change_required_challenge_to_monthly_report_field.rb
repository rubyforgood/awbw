class ChangeRequiredChallengeToMonthlyReportField < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Monthly Report%')

    forms.each do |form|
      field = form.form_fields.find_by(question: "Challenges you'd like to share from this month")
      field.update(is_required: false) unless field.nil?
    end

  end
end
