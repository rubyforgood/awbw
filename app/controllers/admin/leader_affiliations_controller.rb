module Admin
  # Settles the old app's "Leader" affiliations one row at a time: index (choose) →
  # confirm (preview, no writes) → create (perform). AffiliationServices::FoldLegacyLeaders
  # holds the rules.
  class LeaderAffiliationsController < ApplicationController
    def index
      authorize! :data_health

      @rows = AffiliationServices::FoldLegacyLeaders.new.rows
      @pre_outcome = outcome_params
    end

    def confirm
      authorize! :data_health, to: :repair?

      @outcome = outcome_params
      @changes = AffiliationServices::FoldLegacyLeaders.new.planned_changes(outcome: @outcome)
      redirect_to admin_leader_affiliations_path(outcome: @outcome), notice: "Nothing selected to change." if @changes.empty?
    end

    def create
      authorize! :data_health, to: :repair?

      changed = AffiliationServices::FoldLegacyLeaders.new.apply(outcome: outcome_params)
      redirect_to admin_leader_affiliations_path, notice: "Changed #{changed} Leader #{'affiliation'.pluralize(changed)}."
    end

    private

    # Dynamic keys, so read as a plain string hash (never mass-assigned); the service only
    # acts on a row's known choices.
    def outcome_params
      raw = params[:outcome]
      return {} unless raw.respond_to?(:each_pair)

      raw.each_pair.to_h { |key, value| [ key.to_s, value.to_s ] }
    end
  end
end
