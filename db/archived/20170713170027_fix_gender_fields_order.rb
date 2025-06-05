class FixGenderFieldsOrder < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')

    forms.each do |f|
      puts "Updating #{f.name}..."

      field = f.form_fields.find_by(question: "Gender Identity")

      field.answer_options.find_by(name: "Female").update(order: 20)
      field.answer_options.find_by(name: "Male").update(order: 30)
      field.answer_options.find_by(name: "Other").update(order: 40)
    end
  end
end
