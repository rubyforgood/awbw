module DataHealth
  # Organizations whose stored `organization_status` disagrees with what their
  # facilitator affiliations say. The column is legacy and nothing reads it for a
  # decision (ADR-0001 D3a) — this surfaces the drift the org edit form warns about,
  # counted across every organization at once.
  #
  # Report-only on purpose. The stored vocabulary has no value that means
  # "never active" the way the derived bucket does, and the affiliation callbacks
  # only ever write Active/Inactive, so any automatic rewrite would drift straight
  # back. Deciding what these organizations should say is a human call.
  class LegacyOrganizationStatusDrift < Check
    def title = "Organizations whose stored status contradicts their affiliations"

    def explanation
      "The legacy status column was maintained by hand and has drifted. Nothing reads it for a " \
      "decision, so this is informational — an organization is active because someone facilitates " \
      "there, not because the column says so."
    end

    def scope
      Organization.where(id: drifted_ids).includes(:organization_status)
    end

    def describe(organization)
      deco = organization.decorate
      "#{organization.name} — stored #{organization.organization_status&.name.presence || 'none'}, " \
      "affiliations say #{deco.organization_status_label}"
    end

    private

    # Per derived bucket, the organizations in it whose stored status maps to a
    # different bucket (a missing status counts as a mismatch unless the bucket is
    # the one a missing status maps to).
    def drifted_ids
      OrganizationStatus::PROGRAM_STATUS_BUCKETS.values.uniq.flat_map do |bucket|
        ids = status_ids_for(bucket)
        in_bucket = Organization.program_status(bucket)
        next in_bucket.pluck(:id) if ids.empty?

        in_bucket.where(
          "organizations.organization_status_id IS NULL OR organizations.organization_status_id NOT IN (?)", ids
        ).pluck(:id)
      end
    end

    def status_ids_for(bucket)
      names = OrganizationStatus::PROGRAM_STATUS_BUCKETS.select { |_name, b| b == bucket }.keys
      OrganizationStatus.where(name: names).pluck(:id)
    end
  end
end
