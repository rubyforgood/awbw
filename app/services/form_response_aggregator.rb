# Rolls up every submission to one form into a per-question report the results
# page renders: selectable questions become chartable [ label, count ] tallies
# (with dynamic sector/age-group ids resolved to names and "specify" free text
# split out), free-text questions become lists of the actual answers, and file
# questions a simple answered count. Questions are reported in form order, so the
# page mirrors the form itself.
class FormResponseAggregator
  # One question's rollup. `kind` picks which fields are populated:
  #   :select — rows, chart, multi, specify_rows
  #   :text   — responses
  #   :file   — answered_count only
  FieldReport = Struct.new(
    :field, :label, :kind, :answered_count,
    :rows, :chart, :multi, :specify_rows, :responses,
    keyword_init: true
  )

  # One free-text answer, carrying enough context to list it and link back to
  # the full submission.
  TextResponse = Struct.new(:text, :person_name, :submitted_at, :submission_id, keyword_init: true)

  # Above this many distinct options a pie chart turns unreadable, so a single
  # select falls back to a horizontal bar (multi-select always uses a bar since
  # its counts can exceed the submission total).
  PIE_OPTION_LIMIT = 6

  # Geographic fields chart as choropleths (same as the registrant breakdowns),
  # keyed by field_identifier regardless of the field's answer type — a state or
  # country captured as free text still maps. The map matches full state names or
  # USPS abbreviations / country names, and lists exact counts in the legend for
  # anything it can't place. Legacy "agency_" spellings resolve via aliases.
  US_STATE_IDENTIFIERS = (%w[mailing_state ce_license_issuing_state] +
    FormField.aliased_identifiers("organization_state")).to_set
  COUNTRY_IDENTIFIERS = (%w[mailing_country] +
    FormField.aliased_identifiers("organization_country")).to_set

  def initialize(form)
    @form = form
  end

  def submission_count
    submissions.size
  end

  def respondent_count
    submissions.map(&:person_id).uniq.size
  end

  def first_submitted_at
    submissions.map(&:created_at).min
  end

  def last_submitted_at
    submissions.map(&:created_at).max
  end

  def question_count
    input_fields.size
  end

  def any_submissions?
    submissions.any?
  end

  def field_reports
    @field_reports ||= input_fields.map { |field| build_report(field) }
  end

  private

  def submissions
    @submissions ||= @form.form_submissions.includes(:person).to_a
  end

  def submission_by_id
    @submission_by_id ||= submissions.index_by(&:id)
  end

  def input_fields
    @input_fields ||= @form.form_fields.select(&:collects_input?).sort_by { |field| field.position.to_i }
  end

  def answers_by_field_id
    @answers_by_field_id ||= FormAnswer.where(form_submission_id: submissions.map(&:id)).group_by(&:form_field_id)
  end

  def build_report(field)
    answers = answers_by_field_id.fetch(field.id, [])
    return build_map_report(field, answers, :map) if US_STATE_IDENTIFIERS.include?(field.field_identifier)
    return build_map_report(field, answers, :world_map) if COUNTRY_IDENTIFIERS.include?(field.field_identifier)
    return build_select_report(field, answers) if field.selectable?
    return build_file_report(field, answers) if field.file_upload?

    build_text_report(field, answers)
  end

  # A choropleth tally of a geographic field: counts per submitted place value,
  # left as-is (the map matches state/country names itself; the legend lists the
  # exact counts). Multi-value answers split like any other select.
  def build_map_report(field, answers, chart)
    tally = Hash.new(0)
    answered = 0

    answers.each do |answer|
      values = split_values(answer.submitted_answer)
      next if values.empty?

      answered += 1
      values.each { |raw| tally[raw] += 1 }
    end

    FieldReport.new(
      field: field, label: field.name, kind: :map, answered_count: answered,
      rows: tally.sort_by { |label, count| [ -count, label ] }, chart: chart
    )
  end

  def build_select_report(field, answers)
    tally = Hash.new(0)
    specify = Hash.new(0)
    answered = 0
    # Resolved once per field (a query for dynamic fields), not per answer.
    specify_labels = field.specify_option_labels.to_set

    answers.each do |answer|
      values = split_values(answer.submitted_answer)
      next if values.empty?

      answered += 1
      values.each do |raw|
        label, detail = classify_option(field, raw, specify_labels)
        tally[label] += 1
        specify[detail] += 1 if detail
      end
    end

    rows = tally.sort_by { |label, count| [ -count, label ] }
    FieldReport.new(
      field: field, label: field.name, kind: :select, answered_count: answered,
      rows: rows, chart: chart_for(field, rows), multi: field.multi_select_checkbox?,
      specify_rows: specify.sort_by { |text, count| [ -count, text ] }
    )
  end

  def build_text_report(field, answers)
    responses = answers.filter_map do |answer|
      text = answer.submitted_answer.to_s.strip
      next if text.blank?

      submission = submission_by_id[answer.form_submission_id]
      TextResponse.new(
        text: text,
        person_name: submission&.person&.name,
        submitted_at: submission&.created_at,
        submission_id: answer.form_submission_id
      )
    end.sort_by { |response| response.submitted_at || Time.zone.at(0) }.reverse

    FieldReport.new(field: field, label: field.name, kind: :text, answered_count: responses.size, responses: responses)
  end

  def build_file_report(field, answers)
    FieldReport.new(
      field: field, label: field.name, kind: :file,
      answered_count: answers.count { |answer| answer.submitted_answer.present? }
    )
  end

  # Multi-select answers are stored comma+space-joined; single-select answers are
  # a lone value. Splitting on ", " handles both (matching resolve_answer_text).
  def split_values(raw)
    raw.to_s.split(", ").map(&:strip).reject(&:blank?)
  end

  # Maps a stored token to its display label plus, for a "specify" answer, the
  # free text the respondent typed. "Other: Facebook" tallies under "Other" and
  # surfaces "Facebook" as a specify detail; a bare "Other" has no detail.
  def classify_option(field, raw, specify_labels)
    resolved = resolve_dynamic(field, raw)
    base, detail = resolved.split(": ", 2)
    return [ base, detail&.strip.presence ] if specify_labels.include?(base)

    [ resolved, nil ]
  end

  # Sector/age-group fields store a record id; every other field stores the
  # option label verbatim. Unresolvable tokens (free text) pass through.
  def resolve_dynamic(field, raw)
    case field.field_identifier
    when *FormField::SECTOR_FIELD_IDENTIFIERS
      sector_names[raw] || raw
    when *FormField::AGE_GROUP_FIELD_IDENTIFIERS
      category_names[raw] || raw
    else
      raw
    end
  end

  def sector_names
    @sector_names ||= Sector.pluck(:id, :name).to_h { |id, name| [ id.to_s, name ] }
  end

  def category_names
    @category_names ||= Category.pluck(:id, :name).to_h { |id, name| [ id.to_s, name ] }
  end

  def chart_for(field, rows)
    return :bar if field.multi_select_checkbox?

    rows.size > PIE_OPTION_LIMIT ? :bar : :pie
  end
end
