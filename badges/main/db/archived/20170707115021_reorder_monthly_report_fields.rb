class ReorderMonthlyReportFields < ActiveRecord::Migration
  def change
    questions = ["If this is a quote or story from a participant please indicate the following", "Age", "Gender Identity", "Service Population"]

    forms = FormBuilder.where('name LIKE ?', '%Monthly Report%')

    print "Disabling fields that we are not longer needed: "

    forms.each do |form|
      questions.each do |q|
        print "-"
        field = form.form_fields.find_by(question: q)
        field.update(status: 0)
      end
    end

    print "\nUpdating some question labels: "
    
    forms.each do |form|
      print "."
      field = form.form_fields.
              find_by(question: "Any challenges you'd like to share from this month")
      field.update(question: "Share challenges for this month") unless field.nil?
    end
  end
end
