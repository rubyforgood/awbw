class TransferGuideController < ApplicationController
  # Admin-facing reference explaining what changes across every page when a
  # registration is transferred. Linked from Features & tips. (#1944)
  def show
    authorize! :transfer_guide, to: :show?
  end
end
