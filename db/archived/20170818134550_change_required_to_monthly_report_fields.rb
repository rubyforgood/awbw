class ChangeRequiredToMonthlyReportFields < ActiveRecord::Migration
  def change
    questions = ["Share challenges for this month",
                 "Share a highlight for this month",
                 "List any Windows Program staff changes this month",
                 "Anything we can do to help you?"]

    forms = FormBuilder.where('name LIKE ?', '%Monthly Report%')

    forms.each do |form|
      questions.each do |q|
        field = form.form_fields.find_by(question: q)
        field.update(is_required: false) unless field.nil?
      end
    end

  end
end
