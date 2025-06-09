class UpdateEthnicityHintToMonthlyReport < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')

    forms.each do |f|
      field = f.form_fields.find_by(question: "Ethnicity")
      field.update(instructional_hint: "Do your best to estimate the ethnicity of participants you had in this group") unless field.nil?
    end
  end
end
