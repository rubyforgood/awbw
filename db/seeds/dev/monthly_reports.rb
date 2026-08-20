# MonthlyReport seeds (dev-only) - run on their own via `rake db:seed:monthly_reports`,
# or as part of `rake db:seed:dev`. Builds monthly report history for Aisha and a few
# admin reports. The Aisha lookups below are also performed by the workshop-log seeds;
# they are repeated here so this file stands alone.

aisha_user = User.find_by(email: "aisha.user@example.com")
aisha_org = aisha_user&.person&.affiliations&.first&.organization || Organization.first

puts "Creating MonthlyReports…"
if MonthlyReport.none?
  adult_mr_fb    = FormBuilder.find_by(id: 4)
  children_mr_fb = FormBuilder.find_by(id: 2)

  # Stub the MR form fields in dev. (Production seeds them via migrations.) One
  # canonical wording per question is used across both form_builders so seeds
  # don't duplicate the wording variants prod accumulated over time.
  mr_question_specs = [
    { key: :ongoing,       question: MonthlyReport::PARTICIPANT_ONGOING_QUESTION,    answer_type: :free_form_input_one_line,  answer_datatype: :number_integer,    position: 10 },
    { key: :first_time,    question: MonthlyReport::PARTICIPANT_FIRST_TIME_QUESTION, answer_type: :free_form_input_one_line,  answer_datatype: :number_integer,    position: 9 },
    { key: :highlight,     question: "Share a highlight for this month",                  answer_type: :free_form_input_paragraph, answer_datatype: :text_alphanumeric, position: 8 },
    { key: :challenges,    question: "Share challenges for this month",                   answer_type: :free_form_input_paragraph, answer_datatype: :text_alphanumeric, position: 7 },
    { key: :staff_changes, question: "List any Windows Program staff changes this month", answer_type: :free_form_input_paragraph, answer_datatype: :text_alphanumeric, position: 6 },
    { key: :help,          question: "Anything we can do to help you?",                   answer_type: :free_form_input_paragraph, answer_datatype: :text_alphanumeric, position: 5 }
  ]

  mr_form_fields = {}
  [ adult_mr_fb, children_mr_fb ].compact.each do |fb|
    form = fb.forms.first || fb.forms.create!
    mr_form_fields[fb.id] = mr_question_specs.to_h do |spec|
      ff = form.form_fields.where(name: spec[:question], status: 1)
                           .first_or_create!(answer_type: spec[:answer_type],
                                             input_type: spec[:answer_datatype],
                                             position: spec[:position])
      [ spec[:key], ff ]
    end
  end

  fb_for_windows_type = ->(wt) {
    if wt&.short_name == "Children" && children_mr_fb
      children_mr_fb
    else
      adult_mr_fb
    end
  }

  highlight_samples = [
    "Participants opened up about their goals in ways they hadn't before. The collage activity drew out a lot of joy.",
    "A first-time participant shared that the workshop was the first space she'd felt safe in months.",
    "We finished a group project that everyone contributed to — it's now hanging in the common area.",
    "Two long-time participants stepped into peer-leader roles this month."
  ]
  challenges_samples = [
    "Attendance dipped mid-month due to weather and transit disruptions.",
    "We had a hard time keeping the teen group focused after a difficult facility incident.",
    "Supplies ran short toward the end of the month; we improvised with paper and pens.",
    "Several participants moved out of the shelter, breaking continuity for the group."
  ]
  staff_changes_samples = [
    "No staff changes this month.",
    "Welcomed a new co-facilitator on the 15th — she's been a great addition.",
    "Our intern wrapped up her placement. We're recruiting a replacement.",
    "Lead facilitator out for two sessions on family leave."
  ]
  help_samples = [
    "Additional watercolor supplies would let us run the journal workshop more often.",
    "More guidance on facilitating mixed-age groups would be welcome.",
    "Continued support with translation materials for our Spanish-speaking participants.",
    "Nothing additional at this time — thank you for the check-in."
  ]

  mr_sector_pool = Sector.all.to_a
  mr_quote_pool  = Quote.all.to_a

  create_monthly_report = ->(organization:, created_by:, date:) {
    wt = organization&.windows_type || WindowsType.first
    report = MonthlyReport.create!(
      organization_id: organization.id,
      windows_type_id: wt.id,
      created_by_id: created_by.id,
      date: date,
      created_at: date,
      updated_at: date
    )
    fb = fb_for_windows_type.call(wt)
    fields = fb && mr_form_fields[fb.id]
    if fields
      answers = {
        ongoing:       rand(10..50).to_s,
        first_time:    rand(2..15).to_s,
        highlight:     highlight_samples.sample,
        challenges:    challenges_samples.sample,
        staff_changes: staff_changes_samples.sample,
        help:          help_samples.sample
      }
      answers.each do |key, value|
        ReportFormFieldAnswer.create!(report_id: report.id,
                                      form_field: fields[key],
                                      answer: value)
      end
    end

    # ~50% of MRs get sectors (matches prod's 52%)
    if mr_sector_pool.any? && rand < 0.5
      mr_sector_pool.sample(rand(1..3)).each do |sector|
        SectorableItem.find_or_create_by!(sector_id: sector.id,
                                          sectorable_type: "Report",
                                          sectorable_id: report.id)
      end
    end

    # ~65% of MRs get a quote (matches prod's 66%)
    if mr_quote_pool.any? && rand < 0.65
      QuotableItemQuote.find_or_create_by!(quotable_type: "Report",
                                           quotable_id: report.id,
                                           quote: mr_quote_pool.sample)
    end

    report
  }

  if aisha_user
    # 30 monthly reports for Aisha (30 months of history)
    30.times do |i|
      create_monthly_report.call(
        organization: aisha_org,
        created_by: aisha_user,
        date: (Date.today - i.months).beginning_of_month
      )
    end

    # Additional batches under varying older dates to mimic prod's long tail
    report_counts = [ 15, 12, 9, 7, 5, 4, 3, 2, 1, 1 ]
    report_counts.each_with_index do |count, batch|
      count.times do |i|
        create_monthly_report.call(
          organization: aisha_org,
          created_by: aisha_user,
          date: (Date.today - (i + batch * 2).months).beginning_of_month
        )
      end
    end
  end

  # A few monthly reports for the admin user as well
  admin_user = User.first
  if admin_user && admin_user != aisha_user
    5.times do
      create_monthly_report.call(
        organization: Organization.all.sample || aisha_org,
        created_by: admin_user,
        date: (Date.today - rand(1..30).months).beginning_of_month
      )
    end
  end
  puts "  Created #{MonthlyReport.count} monthly reports total"
end
