class MonthlyReport < Report

  def on_going_participants
    if form_builder
      field = form_builder.form_fields.find_by(question: 'Total # On-going Participants', status: 1)
      field.answer(self) if field
    end
  end

  def new_participants
    if form_builder
      field = form_builder.form_fields.find_by(question: 'Total # First-Time Participants', status: 1)
      field.answer(self) if field
    end
  end

  def month
    date.strftime("%B")
  end

end
