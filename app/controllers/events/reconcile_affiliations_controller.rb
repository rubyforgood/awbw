module Events
  # The "Reconcile affiliations" bulk action: a preview-and-confirm page that
  # brings each registrant's owned facilitator affiliation in line with whether
  # they actually completed this facilitator training. Post-event it same-days the
  # affiliations of non-completers; the admin can opt individual rows out before
  # applying. Only facilitator-training events have facilitator affiliations to
  # reconcile, so the action is limited to them.
  class ReconcileAffiliationsController < ApplicationController
    include AhoyTracking
    before_action :set_event
    before_action :require_facilitator_training

    def index
      authorize! @event, to: :reconcile_affiliations?
      track_view("events.reconcile_affiliations", { event_id: @event.id })

      @rows = AffiliationServices::ReconcileEvent.new(@event).preview
      @event = @event.decorate
    end

    def create
      authorize! @event, to: :reconcile_affiliations?

      changed = AffiliationServices::ReconcileEvent.new(@event).apply(included_keys: params[:included])
      redirect_to registrants_event_path(@event), notice: reconcile_notice(changed)
    end

    private

    def set_event
      @event = Event.find(params[:id])
    end

    def require_facilitator_training
      return if @event.facilitator_training?

      redirect_to registrants_event_path(@event),
                  alert: "Affiliation reconciliation applies to facilitator trainings only."
    end

    def reconcile_notice(changed)
      return "No affiliations needed reconciling." if changed.zero?

      "Reconciled #{changed} #{'affiliation'.pluralize(changed)}."
    end
  end
end
