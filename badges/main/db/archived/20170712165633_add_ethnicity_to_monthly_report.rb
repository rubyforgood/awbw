class AddEthnicityToMonthlyReport < ActiveRecord::Migration
  def change
    forms = FormBuilder.where('name LIKE ?', '%Workshop Log%')

    questions = []

    forms.each do |f|
      q = "%Please indicate any details that apply to this workshop%"
      field = f.form_fields.where('question LIKE ?', q).first
      field.update(status: 0) unless field.nil?

      q = "Total # On-Going Participants"
      field = f.form_fields.find_by(question: q)
      field.update(instructional_hint: "On-Going means those who have done art with you at least once before.", ordering: 1050) unless field.nil?

      q = "Total # First-Time Participants"
      field = f.form_fields.find_by(question: q)
      field.update(instructional_hint: "First-Time means those who have never done art with you before, can only be first-time once.", ordering: 1000) unless field.nil?

      # Adding Gender identity
      f.form_fields << FormField.new(question: "Gender Identity", instructional_hint: "Select all that apply", ordering: 900,
                                     answer_type: 4, is_required: true, status: 1)

      field = f.form_fields.find_by(question: "Gender Identity")
      field.answer_options << AnswerOption.new(name: "Female", order: 40)
      field.answer_options << AnswerOption.new(name: "Male", order: 30)
      field.answer_options << AnswerOption.new(name: "Other", order: 20)

      # Adding Ethnicity
      f.form_fields << FormField.new(question: "Ethnicity",
                                     instructional_hint: "Enter in an estimated number of people who fall under these ethnicities",
                                     ordering: 850, answer_type: 3, status: 1)

      [ ["African American", 800], ["White", 750], ["Asian/Pacific Islander", 700],
        ["Native American", 650], ["Latino/a", 600], ["Other", 600] ].each do |e|

        f.form_fields << FormField.new(question: e[0], ordering: e[1], answer_type: 0, status: 1)
      end

      # Adding a new "hack" Hint
      f.form_fields << FormField.new(question: "",
           instructional_hint: "Based on your overall observations of the participants' experiences with this workshop, please answer the following",
           ordering: 550, answer_type: 3, status: 1)

      q = "Highlights/Successes"
      field = f.form_fields.find_by(question: q)
      field.update(question: "Please share any highlights/successes") unless field.nil?

      q = "Challenges/Difficulties"
      field = f.form_fields.find_by(question: q)
      field.update(question: "Please share any challenges/difficulties") unless field.nil?
    end
  end
end
