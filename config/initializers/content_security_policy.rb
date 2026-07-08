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
    # Browsers POST violation reports here; CspReportsController#create logs them
    # and returns 204. Keep this path in sync with the route.
    policy.report_uri "/csp-violation-report-endpoint"
  end
  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = true
end
