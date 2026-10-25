module DataHealth
  # Whether an admin has told the portal which organization it runs as, and which
  # addresses its invoices print. Each of these falls back to the deployment's own
  # configuration, so an unset one is silent until it prints the wrong thing.
  class UnconfiguredAppSettings < Check
    def title = "App settings not configured"

    def explanation
      sentence = "Invoices, receipts and the public contact page print these. Until they're chosen " \
                 "the portal falls back to the values the deployment was configured with, which " \
                 "nobody can see or correct from here."
      return sentence if missing.empty?

      "#{sentence} Not chosen: #{missing.to_sentence}."
    end

    # The settings row either names everything or doesn't, so this counts the
    # singleton — including the deployment where no row exists yet.
    def count
      @count ||= missing.any? ? 1 : 0
    end

    def flagged? = any?

    def lists_rows? = false

    def scope = Setting.none

    def review_path = admin_settings_path

    def review_label = "App settings"

    private

    # The associations, not the readers that resolve a fallback, so a value only
    # ENV supplies still reads as unset.
    def missing
      @missing ||= begin
        setting = Setting.current
        organization = setting.organization

        [].tap do |labels|
          labels << "the organization this portal runs as" if organization.blank?
          labels << "a tax ID on #{organization.name}" if organization.present? && organization.tax_id.blank?
          labels << "a return address for invoices" if setting.return_address.blank?
          labels << "a remittance address for checks" if setting.remittance_address.blank?
          labels << "who signs CE certificates" if setting.ce_administrator.blank? && ContinuingEducationRegistration.exists?
        end
      end
    end
  end
end
