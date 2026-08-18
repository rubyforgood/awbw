module Events
  # The "Reconcile affiliations" bulk action: index (edit) → confirm (preview, no
  # writes) → create (perform). `AffiliationServices::ReconcilePerson` holds the rules.
  class ReconcileAffiliationsController < ApplicationController
    include AhoyTracking
    before_action :set_event

    def index
      authorize! @event, to: :reconcile_affiliations?
      track_view("events.reconcile_affiliations", { event_id: @event.id })

      reconcile = AffiliationServices::ReconcileEvent.new(@event)
      @person_groups = reconcile.actionable_person_groups
      @skipped_sections = reconcile.skipped_reason_sections
      @has_rows = reconcile.any_rows?
      # Restore the admin's per-row radio choices when they come back from confirm.
      @pre_outcome = params[:outcome]
      @event = @event.decorate
    end

    def confirm
      authorize! @event, to: :reconcile_affiliations?

      @outcome = outcome_params
      @changes = AffiliationServices::ReconcileEvent.new(@event).planned_changes(outcome: @outcome)
      @event = @event.decorate

      redirect_to reconcile_affiliations_event_path(@event), notice: "Nothing selected to change." and return if @changes.empty?
    end

    def create
      authorize! @event, to: :reconcile_affiliations?

      changed = AffiliationServices::ReconcileEvent.new(@event).apply(outcome: outcome_params)
      redirect_to registrants_event_path(@event), notice: reconcile_notice(changed)
    end

    private

    def set_event
      @event = Event.find(params[:id])
    end

    # Dynamic keys, so read as a plain string hash (never mass-assigned); the service
    # only acts on known choices.
    def outcome_params
      raw = params[:outcome]
      return {} unless raw.respond_to?(:each_pair)

      raw.each_pair.map { |key, value| [ key.to_s, value.to_s ] }.to_h
    end

    def reconcile_notice(changed)
      return "No affiliations needed reconciling." if changed.zero?

      "Reconciled #{changed} #{'affiliation'.pluralize(changed)}."
    end
  end
end
