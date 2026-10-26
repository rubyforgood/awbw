module Analytics
  # Collects every Ahoy event that belongs to an organization's history: the org
  # record itself, its own nested records, and the records on its "Associated
  # records" panel — current ones by id, deleted ones through the owner their
  # delete snapshot names, so a merged-away or removed record stays listed.
  # Powers the `organization_id` filter on the admin Ahoy activities index;
  # #change_log narrows it to the org and its addresses for the edit page.
  class OrganizationActivityEvents
    # A lifecycle event records the STI subclass it was fired on, never the base
    # class, so each subclass needs its own key against the same ids.
    REPORT_TYPES = %w[Report MonthlyReport ReportStory].freeze
    PAYMENT_TYPES = [ "Payment", *PersonActivityEvents::PAYMENT_SUBCLASSES ].freeze

    # How a deleted record's destroy snapshot points back at the organization. A
    # polymorphic belongs_to is keyed by its association name.
    DELETED_RECORD_OWNERS = {
      "Address" => "addressable",
      "ContactMethod" => "contactable",
      "Comment" => "commentable",
      "Grant" => "funder",
      "Invoice" => "invoicee"
    }.merge(
      %w[Affiliation EventRegistrationOrganization CommunityNews Story StoryIdea WorkshopLog
         Resource WorkshopVariation WorkshopVariationIdea].index_with { "organization_id" },
      (REPORT_TYPES + PAYMENT_TYPES).index_with { "organization_id" }
    ).freeze

    def initialize(organization)
      @organization = organization
    end

    def relation
      scopes = resource_ids_by_type.map { |type, ids| Ahoy::Event.where(resource_type: type, resource_id: ids) }
      deleted_record_ids.each { |type, ids| scopes << Ahoy::Event.where(resource_type: type, resource_id: ids) }
      scopes.reduce(:or)
    end

    def change_log
      Ahoy::Event.where(resource_type: "Organization", resource_id: @organization.id)
        .or(Ahoy::Event.where(resource_type: "Address", resource_id: @organization.addresses.select(:id)))
        .or(Ahoy::Event.where(resource_type: "Address", resource_id: deleted_record_ids["Address"].to_a))
    end

    private

    # resource_type => ids (arrays or id-only subqueries). Mirrors the records in
    # organizations/_associated_records plus the org's own nested records.
    def resource_ids_by_type
      org_filter = { organization_id: @organization.id }
      map = {
        "Organization" => [ @organization.id ],
        "Address" => @organization.addresses.select(:id),
        "ContactMethod" => @organization.contact_methods.select(:id),
        "Comment" => @organization.comments.reorder(nil).select(:id),
        "Affiliation" => @organization.affiliations.select(:id),
        "EventRegistrationOrganization" => @organization.event_registration_organizations.select(:id),
        "EventRegistration" => registration_ids,
        "CommunityNews" => CommunityNews.where(org_filter).select(:id),
        "Story" => Story.where(org_filter).select(:id),
        "StoryIdea" => StoryIdea.where(org_filter).select(:id),
        "WorkshopLog" => @organization.workshop_logs.select(:id),
        "Resource" => Resource.where(org_filter).select(:id),
        "WorkshopVariation" => WorkshopVariation.where(org_filter).select(:id),
        "WorkshopVariationIdea" => WorkshopVariationIdea.where(org_filter).select(:id),
        "Grant" => @organization.grants.select(:id),
        "Invoice" => @organization.invoices.select(:id)
      }
      REPORT_TYPES.each { |type| map[type] = @organization.reports.select(:id) }
      PAYMENT_TYPES.each { |type| map[type] = Payment.where(org_filter).select(:id) }
      map
    end

    # A registration reaches the org only through its link row, so a deleted link
    # still names the registration it tied to the org.
    def registration_ids
      @organization.event_registration_organizations.pluck(:event_registration_id) | unlinked_registration_ids
    end

    # resource_type => ids of the org's records that have since been deleted.
    def deleted_record_ids
      @deleted_record_ids ||= deleted_records.each_with_object({}) do |(type, id, _registration_id), found|
        (found[type] ||= []) << id
      end
    end

    def unlinked_registration_ids
      deleted_records.filter_map { |type, _id, registration_id| registration_id&.to_i if type == "EventRegistrationOrganization" }
    end

    # [resource_type, id, event_registration_id] for every destroy event whose
    # snapshot names this organization.
    def deleted_records
      @deleted_records ||= Ahoy::Event.where(name: destroy_event_names)
        .where(DELETED_RECORD_OWNERS.map { |type, column| owner_condition(type, column) }.join(" OR "))
        .distinct
        .pluck(:resource_type, :resource_id, Arel.sql("JSON_EXTRACT(ahoy_events.properties, '$.attributes.event_registration_id')"))
    end

    def destroy_event_names
      DELETED_RECORD_OWNERS.keys.map { |type| "destroy.#{type.constantize.table_name.singularize}" }.uniq
    end

    def owner_condition(type, column)
      id_column = column.end_with?("_id") ? column : "#{column}_id"
      condition = Ahoy::Event.sanitize_sql_array(
        [ "ahoy_events.resource_type = ? AND CAST(JSON_EXTRACT(ahoy_events.properties, ?) AS UNSIGNED) = ?",
          type, "$.attributes.#{id_column}", @organization.id ]
      )
      return "(#{condition})" if column == id_column

      type_match = Ahoy::Event.sanitize_sql_array(
        [ "JSON_UNQUOTE(JSON_EXTRACT(ahoy_events.properties, ?)) = 'Organization'", "$.attributes.#{column}_type" ]
      )
      "(#{condition} AND #{type_match})"
    end
  end
end
