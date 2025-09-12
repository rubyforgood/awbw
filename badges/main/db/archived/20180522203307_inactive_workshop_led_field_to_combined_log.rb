class InactiveWorkshopLedFieldToCombinedLog < ActiveRecord::Migration
  def change
    form = FormBuilder.where('name LIKE ?', '%Family Workshop Log%').first
    field = form.form_fields.find_by(question: "Workshop Led")
    field.update(status: 0) unless field.nil?
  end
end
