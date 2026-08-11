# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https
    # No report_uri: nothing in the app serves a violation-report endpoint, so
    # setting one only makes browsers POST reports to a dead path (404 noise in
    # the console). Reinstate it only alongside a route that accepts the reports.
  end

  # Nonce every inline <script> so it survives an enforced script-src (some
  # environments enforce this policy at the edge even though the app ships it
  # report-only). Chartkick reads content_security_policy_nonce automatically, so
  # its report-suite charts stop being blocked and no longer hang on "Loading…".
  # csp_meta_tag (in the layout) hands the same nonce to Turbo so it re-applies it
  # to scripts across Turbo Drive navigations.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[ script-src ]

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = true
end
