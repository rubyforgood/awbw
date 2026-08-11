# Builds a LinkedIn "Add to Profile" deep link that pre-fills the member's
# "Licenses & certifications" form (startTask=CERTIFICATION_NAME). This click-to-add
# flow is the only generally-available path — LinkedIn's write API is partner-gated —
# so the member follows the link and confirms; we never write to their profile.
#
# A numeric organizationId links the credential to AWBW's LinkedIn Page (logo + link)
# and is preferred when available; otherwise we fall back to the free-text
# organizationName, which still fills the form but without the linked Page.
class LinkedinAddToProfileUrl
  BASE_URL = "https://www.linkedin.com/profile/add".freeze

  def initialize(name:, issued_on:, cert_url:, cert_id:, organization_name:, organization_id: nil)
    @name = name
    @issued_on = issued_on
    @cert_url = cert_url
    @cert_id = cert_id
    @organization_name = organization_name
    @organization_id = organization_id
  end

  def to_s
    "#{BASE_URL}?#{params.to_query}"
  end

  private

  def params
    {
      startTask: "CERTIFICATION_NAME",
      name: @name,
      issueYear: @issued_on&.year,
      issueMonth: @issued_on&.month,
      certUrl: @cert_url,
      certId: @cert_id
    }.merge(organization_params).compact
  end

  def organization_params
    return { organizationId: @organization_id } if @organization_id.present?
    { organizationName: @organization_name }
  end
end
