module Events
  # The "Reconcile affiliations" bulk action: a preview-and-confirm page that
  # brings each registrant's owned facilitator affiliation in line with reality.
  # For a facilitator training it creates missing affiliations, same-days
  # non-completers, and reactivates late attendees; for a non-training event it
  # removes facilitator affiliations that were auto-created off it. The admin can
  # opt individual rows out (and, for same-day rows, delete instead) before applying.
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

    # Step 2: show exactly what "Perform changes" will do (no writes yet).
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

    # `outcome` is a { row.key => choice } map with dynamic keys, read as a plain
    # string hash (never mass-assigned); the service only acts on known choices.
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
