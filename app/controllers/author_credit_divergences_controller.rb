class AuthorCreditDivergencesController < ApplicationController
  before_action :authorize_page

  FILTER_KEYS = %i[person_id type preference include_reconciled].freeze

  def index
    @groups = AuthorCreditDivergenceQuery.new(**filters.symbolize_keys).call

    return unless turbo_frame_request?
    render :author_credit_divergences_results
  end

  # Resolve a whole person: point their profile at one preference and stamp them
  # reconciled so a deliberate divergence stops reappearing on the worklist.
  def update_person
    person = Person.find(params[:id])
    person.assign_attributes(person_params)
    person.author_credit_reconciled_at = Time.current
    person.updated_by = current_user

    if person.save
      redirect_to author_credit_divergences_path(filters), notice: "Updated credit preferences for #{person.full_name}."
    else
      redirect_to author_credit_divergences_path(filters), alert: person.errors.full_messages.to_sentence
    end
  end

  # Resolve a single item by rewriting its stored consent snapshot. Setting
  # "anonymous" here is a live override that suppresses that item's credit alone;
  # any other value only re-records history (see AuthorCreditable).
  def update_item
    model = AuthorCreditDivergenceQuery.model_for(params[:record_type])
    return redirect_to(author_credit_divergences_path(filters), alert: "Unknown record type.") unless model

    record = model.find(params[:record_id])
    record.author_credit_preference = params[:author_credit_preference]
    record.updated_by = current_user if record.respond_to?(:updated_by=)

    if record.save
      redirect_to author_credit_divergences_path(filters), notice: "Updated credit for #{model.name.underscore.humanize.downcase} ##{record.id}."
    else
      redirect_to author_credit_divergences_path(filters), alert: record.errors.full_messages.to_sentence
    end
  end

  private

  def authorize_page
    authorize! :author_credit_divergence, to: :"#{action_name}?", with: AuthorCreditDivergencePolicy
  end

  def person_params
    params.require(:person).permit(:display_name_preference, :contributions_anonymous)
  end

  # Carried through every redirect so the admin lands back on the same filtered list.
  # The write actions deliberately name their own params `id` / `record_type` /
  # `record_id` so a record identifier can never be mistaken for a filter.
  def filters
    params.permit(*FILTER_KEYS).to_h.compact_blank
  end
end
