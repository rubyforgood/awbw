class EventRegistrationImporter
  # The spreadsheet columns the importer reads, and how a cell becomes a value.
  # Header labels are matched loosely: case, spacing, and punctuation are ignored, so
  # "First name", "FirstName", and "first_name" all land on :first_name.
  module Columns
    HEADER_ALIASES = {
      first_name: %w[firstname first],
      last_name: %w[lastname last surname name],
      email: %w[email emailaddress primaryemail],
      nickname: %w[nickname preferrednickname preferredname],
      pronouns: %w[pronouns],
      secondary_email: %w[secondaryemail email2 alternateemail],
      status: %w[status attendancestatus registrationstatus],
      registered_on: %w[registeredon registered registrationdate dateregistered registeredat dateentered],
      organization: %w[organization organisation org organizationname],
      position: %w[position title jobtitle positiontitle organizationposition],
      organization_website: %w[organizationwebsite orgwebsite website],
      organization_type: %w[organizationtype orgtype],
      organization_street: %w[organizationstreet organizationstreetaddress organizationaddress orgstreet orgaddress],
      organization_city: %w[organizationcity orgcity],
      organization_state: %w[organizationstate organizationstateprovince orgstate],
      organization_zip: %w[organizationzip organizationzipcode organizationpostalcode organizationzippostalcode orgzip],
      organization_country: %w[organizationcountry orgcountry],
      mailing_street: %w[street streetaddress address mailingstreet mailingaddress],
      mailing_city: %w[city mailingcity],
      mailing_state: %w[state stateprovince mailingstate],
      mailing_zip: %w[zip zipcode postalcode zippostalcode mailingzip],
      mailing_country: %w[country mailingcountry],
      mailing_address_type: %w[addresstype mailingaddresstype],
      phone: %w[phone phonenumber],
      phone_type: %w[phonetype],
      primary_sector: %w[primarysector],
      additional_sectors: %w[additionalsectors sectors],
      primary_age_group: %w[primaryagegroup primaryagegroupserved],
      additional_age_groups: %w[additionalagegroups additionalagegroupsserved agegroups],
      ce_requested: %w[ce cerequested cecredit cecreditinterest],
      license_kind: %w[licensetype licensekind celicensetype],
      license_number: %w[licensenumber license celicense celicensenumber],
      license_issuing_state: %w[licensestate licenseissuingstate celicensestate],
      license_expires_on: %w[licenseexpires licenseexpiration licenseexpireson licenseexpirationdate],
      scholarship_amount: %w[scholarship scholarshipamount],
      someone_else_will_pay: %w[someoneelsewillpay someoneelsepaid someoneelsepaying],
      invoice_requested: %w[invoicerequested invoice],
      w9_requested: %w[w9requested w9],
      post_survey_completed: %w[postsurveycompleted postsurvey],
      certificate_sent: %w[certificatesent certificatesenton],
      amount_paid: %w[amount amountpaid paid paymentamount paidamount],
      payment_type: %w[type method paymenttype paymentmethod],
      check_number: %w[checknumber check checkno],
      bulk_payment: %w[bulkpayment bulkpaymentref bulkpaymentgroup paymentgroup paymentid]
    }.merge(EventRegistration::DAY_FIELDS.each_with_index.to_h { |_, index| [ :"day_#{index + 1}", [ "day#{index + 1}", "completedday#{index + 1}" ] ] }).freeze

    HEADER_FIELDS = HEADER_ALIASES.flat_map { |field, labels| labels.map { |label| [ label, field ] } }.to_h.freeze

    # The downloadable template's header row: one spelling per readable column, in
    # the order the upload page groups them, so staff start from the exact labels
    # rather than guessing which alias we accept. A spec holds this to every field
    # in HEADER_ALIASES, so a new column can't ship without a place in the template.
    TEMPLATE_HEADERS = %w[
      FirstName LastName EMail Nickname Pronouns SecondaryEmail
      Status Day1 Day2 Day3 Day4 Day5 RegisteredOn
      Organization Position OrganizationWebsite OrganizationType
      OrganizationStreet OrganizationCity OrganizationState OrganizationZip OrganizationCountry
      Street City State Zip Country AddressType Phone PhoneType
      PrimarySector AdditionalSectors PrimaryAgeGroup AdditionalAgeGroups
      CE LicenseType LicenseNumber LicenseState LicenseExpires
      Scholarship AmountPaid PaymentType CheckNumber BulkPayment
      SomeoneElseWillPay InvoiceRequested W9Requested PostSurveyCompleted CertificateSent
    ].freeze

    DAY_KEYS = (1..EventRegistration::DAY_FIELDS.size).to_h { |day| [ day, :"day_#{day}" ] }.freeze

    STATUSES = {
      "registered" => "registered",
      "attended" => "attended",
      "incompleteattendance" => "incomplete_attendance",
      "incomplete" => "incomplete_attendance",
      "partial" => "incomplete_attendance",
      "partialattendance" => "incomplete_attendance",
      "noshow" => "no_show",
      "cancelled" => "cancelled",
      "canceled" => "cancelled"
    }.freeze

    YES = %w[yes y true x 1].freeze
    NO = %w[no n false 0].freeze

    LIST_SEPARATOR = /[;,|\n]/

    SLASHED_DATE = %r{\A(\d{1,2}/\d{1,2}/\d{2,4})\b}

    def self.field_for(label)
      HEADER_FIELDS[compact(label)]
    end

    def self.compact(label)
      label.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end

    # nil when blank (the importer defaults it), :invalid when unrecognized.
    def self.status(raw)
      return if raw.blank?

      STATUSES.fetch(compact(raw), :invalid)
    end

    # true / false for a recognizable yes or no, nil otherwise.
    def self.yes_no(raw)
      token = raw.to_s.strip.downcase
      return true if token.in?(YES)
      return false if token.in?(NO)

      nil
    end

    # US-style slashed dates (a trailing time is ignored); anything else Date.parse reads.
    def self.date(raw)
      text = raw.to_s.strip
      return if text.blank?

      slashed = text.match(SLASHED_DATE)
      return Date.parse(text) unless slashed

      Date.strptime(slashed[1], slashed[1].split("/").last.length == 2 ? "%m/%d/%y" : "%m/%d/%Y")
    rescue Date::Error
      nil
    end

    def self.list(raw)
      raw.to_s.split(LIST_SEPARATOR).map(&:strip).reject(&:blank?)
    end
  end
end
