class DeleteExtraDateFieldWorkshopLogs < ActiveRecord::Migration
  def change
    form = FormBuilder.where('name LIKE ?', '%Family Workshop Log%').first
    field = form.form_fields.find_by(question: "Workshop Date")
    field.update(status: 0)
  end
end
