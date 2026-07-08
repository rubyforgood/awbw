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
  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = true
end
