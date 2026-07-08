# Receives browser Content-Security-Policy violation reports POSTed to the
# policy's report_uri (see config/initializers/content_security_policy.rb) and
# logs them. Inherits from ActionController::Base directly to bypass the
# authentication, authorization, CSRF, and tracking callbacks in
# ApplicationController — browsers send these reports unauthenticated, without a
# CSRF token, and with an "application/csp-report" content type.
class CspReportsController < ActionController::Base
  skip_forgery_protection

  def create
    report = parsed_report
    Rails.logger.info("[CSP violation] #{report.to_json}") if report.present?
    head :no_content
  end

  private

  # The body is JSON shaped like { "csp-report": { ... } }, but its content type
  # ("application/csp-report") isn't one Rails parses, so read it directly.
  def parsed_report
    body = request.body.read
    return {} if body.blank?

    JSON.parse(body).fetch("csp-report", {})
  rescue JSON::ParserError
    {}
  end
end
