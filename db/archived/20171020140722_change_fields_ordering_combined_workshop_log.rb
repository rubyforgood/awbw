class ChangeFieldsOrderingCombinedWorkshopLog < ActiveRecord::Migration
  def change
    form = FormBuilder.where('name LIKE ?', '%Family Workshop Log%').first

    field = form.form_fields.find_by(question: "Adult Ages")
    field.update(ordering: 380)
  end
end
