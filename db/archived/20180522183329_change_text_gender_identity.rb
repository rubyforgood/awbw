class ChangeTextGenderIdentity < ActiveRecord::Migration
  def change
    form = FormBuilder.where('name LIKE ?', '%Family Workshop Log%').first
    field = form.form_fields.find_by(question: "Gender Identity")
    field.update(question: "Gender Identity (all participants)")
  end
end
