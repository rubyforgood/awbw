class AuthorCreditDivergencesController < ApplicationController
  before_action :authorize_page

  FILTER_KEYS = %i[person_id type preference include_reconciled].freeze

  def index
    return unless turbo_frame_request?

    @result = AuthorCreditDivergenceQuery.new(**filters.symbolize_keys).call
    @reconciled_people = Person.where.not(author_credit_reconciled_at: nil)
                               .order(author_credit_reconciled_at: :desc)
    render :author_credit_divergences_results
  end

  # Stamped reconciled so a deliberate divergence stops reappearing on the worklist.
  def update_person
    person = Person.find(params[:id])
    person.assign_attributes(person_params)
    person.author_credit_reconciled_at = Time.current
    person.updated_by = current_user

    if person.save
      render_divergence_change("Updated credit preferences for #{person.full_name}.", :notice)
    else
      render_divergence_change(person.errors.full_messages.to_sentence, :alert)
    end
  end

  # "anonymous" here suppresses this item's credit; any other value only re-records
  # history (see AuthorCreditable).
  def update_item
    model = AuthorCreditDivergenceQuery.model_for(params[:record_type])
    return render_divergence_change("Unknown record type.", :alert) unless model

    record = model.find(params[:record_id])

    # Clearing "anonymous" hands the item back to the profile, which may credit it —
    # that's what this page exists to do.
    record.author_credit_preference = params[:author_credit_preference]
    record.updated_by = current_user if record.respond_to?(:updated_by=)

    if record.save
      render_divergence_change("Updated credit for #{model.name.underscore.humanize.downcase} ##{record.id}.", :notice)
    else
      render_divergence_change(record.errors.full_messages.to_sentence, :alert)
    end
  end

  # The fix for every section below the first: an author_id is the only credit path
  # that follows a profile, links to it, and lists the record there.
  def assign_author
    model = AuthorCreditDivergenceQuery.model_for(params[:record_type])
    return render_divergence_change("Unknown record type.", :alert) unless model

    record = model.find(params[:record_id])
    person = Person.find_by(id: params[:author_id])
    return render_divergence_change("Choose a person to credit.", :alert) unless person

    record.author_id = person.id
    record.updated_by = current_user if record.respond_to?(:updated_by=)

    if record.save
      render_divergence_change("Credited #{model.name.underscore.humanize.downcase} ##{record.id} to #{person.full_name}.", :notice)
    else
      render_divergence_change(record.errors.full_messages.to_sentence, :alert)
    end
  end

  private

  # Re-render the frame over Turbo so a save doesn't flip the whole page.
  def render_divergence_change(message, type)
    respond_to do |format|
      format.turbo_stream do
        flash.now[type] = message
        @result = AuthorCreditDivergenceQuery.new(**filters.symbolize_keys).call
        render :divergence_change
      end
      format.html { redirect_to author_credit_divergences_path(filters), flash: { type => message } }
    end
  end

  def authorize_page
    authorize! :author_credit_divergence, to: :"#{action_name}?", with: AuthorCreditDivergencePolicy
  end

  def person_params
    params.require(:person).permit(:display_name_preference, :anonymous_contributions)
  end

  # The write actions name their params `id` / `record_type` / `record_id` so a
  # record identifier can never be mistaken for a filter.
  def filters
    params.permit(*FILTER_KEYS).to_h.compact_blank
  end
end
