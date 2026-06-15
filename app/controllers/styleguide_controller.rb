class StyleguideController < ApplicationController
  # Internal design reference for comparing page-header treatments.
  # Logged-in only; no model data required, so authorization is skipped.
  skip_verify_authorized

  def headers
  end
end
