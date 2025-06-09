class DeleteExtraGenderFromAdultOk < ActiveRecord::Migration
  def change
    form = FormBuilder.where('name LIKE ?', '%Adult Workshop Log%').first
    field = form.form_fields.find_by(question: "Gender",
                                     instructional_hint: "click all that apply")

    field.update(status: 0) unless field.nil?
  end
end
