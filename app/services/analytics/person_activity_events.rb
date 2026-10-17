module Analytics
  # Collects every Ahoy event that belongs to a person's history: events about
  # the person record itself, about their user account (both lifecycle and
  # `auth.*` events), and about the associated records surfaced on the person's
  # "Associated records" panel — plus the records that only reach a person
  # through a parent (registration children, the money ledger, form answers and
  # their uploads, agreement responses). Powers the person edit "History" card
  # and the `person_id` filter on the admin Ahoy activities index.
  class PersonActivityEvents
    # A lifecycle event records the STI subclass it was fired on ("CashPayment"),
    # never the base class, so each subclass needs its own key against the same ids.
    PAYMENT_SUBCLASSES = %w[ FilemakerPayment ExternalProcessorPayment CheckPayment CashPayment ].freeze

    # How a deleted record's destroy snapshot points back at the person: snapshot
    # column => owner type. A polymorphic belongs_to is keyed by its association
    # name and lists the owner types that make it the person's.
    DELETED_RECORD_OWNERS = {
      "Affiliation" => { "person_id" => "Person" },
      "ProfessionalLicense" => { "person_id" => "Person" },
      "Membership" => { "person_id" => "Person" },
      "Address" => { "addressable" => %w[Person] },
      "ContactMethod" => { "contactable" => %w[Person] },
      "EventRegistration" => { "registrant_id" => "Person" },
      "ContinuingEducationRegistration" => { "event_registration_id" => "EventRegistration" },
      "EventRegistrationChecklistCompletion" => { "event_registration_id" => "EventRegistration" },
      "EventRegistrationOrganization" => { "event_registration_id" => "EventRegistration" },
      "EventAttendanceTimeEntry" => { "event_registration_id" => "EventRegistration" },
      "EventStaff" => { "person_id" => "Person" },
      "FormSubmission" => { "person_id" => "Person" },
      "FormAnswer" => { "form_submission_id" => "FormSubmission" },
      "Asset" => { "owner" => %w[FormAnswer] },
      "Grant" => { "funder" => %w[Person] },
      "Payment" => { "person_id" => "Person" },
      "Allocation" => { "allocatable" => %w[EventRegistration ContinuingEducationRegistration MembershipInvoice] },
      "Refund" => { "recipient" => %w[Person], "refundable" => %w[Payment] },
      "MembershipInvoice" => { "membership_id" => "Membership" },
      "Scholarship" => { "recipient_id" => "Person" },
      "ScholarshipAgreementResponse" => { "scholarship_id" => "Scholarship" },
      "TopicSubscription" => { "person_id" => "Person" },
      "CommunityNews" => { "author_id" => "Person" },
      "Resource" => { "author_id" => "Person" },
      "Story" => { "author_id" => "Person" },
      "StoryIdea" => { "created_by_id" => "User" },
      "Workshop" => { "author_id" => "Person" },
      "WorkshopIdea" => { "created_by_id" => "User" },
      "WorkshopVariation" => { "author_id" => "Person" },
      "WorkshopVariationIdea" => { "created_by_id" => "User" },
      "User" => { "person_id" => "Person" },
      "WorkshopLog" => { "created_by_id" => "User" }
    }.merge(PAYMENT_SUBCLASSES.index_with { { "person_id" => "Person" } }).freeze
    OWNER_TYPES = DELETED_RECORD_OWNERS.values.flat_map(&:values).flatten.uniq.freeze

    def initialize(person)
      @person = person
    end

    def relation
      scopes = resource_scopes
      scopes << auth_scope if @person.user
      return Ahoy::Event.none if scopes.empty?
      scopes.reduce(:or)
    end

    def count
      relation.count
    end

    private

    def resource_scopes
      scopes = resource_ids_by_type.map do |type, ids|
        Ahoy::Event.where(resource_type: type, resource_id: ids)
      end
      deleted_record_ids.each do |type, ids|
        scopes << Ahoy::Event.where(resource_type: type, resource_id: ids.to_a)
      end
      departed = departed_comment_ids
      scopes << Ahoy::Event.where(resource_type: "Comment", resource_id: departed) if departed.any?
      scopes
    end

    # resource_type => ids of the person's records that have since been deleted,
    # matched through the owner their destroy snapshot names. Repeats until no new
    # owner turns up, so a deleted registration brings its deleted CE registration
    # and that one's allocations along.
    def deleted_record_ids
      @deleted_record_ids ||= begin
        found = {}
        owners = live_owner_ids
        while owners.any?
          new_owners = {}
          destroy_events_owned_by(owners).each do |type, id|
            next unless (found[type] ||= Set.new).add?(id)

            (new_owners[owner_key(type)] ||= Set.new) << id
          end
          owners = new_owners
        end
        found
      end
    end

    # The live records a deleted record can name as its owner.
    def live_owner_ids
      map = resource_ids_by_type.slice(*OWNER_TYPES).transform_values do |ids|
        ids.is_a?(Array) ? ids.to_set : ids.pluck(:id).to_set
      end
      map.reject { |_type, ids| ids.empty? }
    end

    def owner_key(type)
      type.safe_constantize&.base_class&.name || type
    end

    # [resource_type, id] for every destroy event whose snapshot names one of
    # these owners.
    def destroy_events_owned_by(owners)
      conditions = DELETED_RECORD_OWNERS.flat_map do |type, columns|
        columns.flat_map { |column, owner_types| owner_conditions(type, column, owner_types, owners) }
      end
      return [] if conditions.empty?

      Ahoy::Event.where(name: destroy_event_names)
        .where(conditions.join(" OR "))
        .distinct.pluck(:resource_type, :resource_id)
    end

    def destroy_event_names
      DELETED_RECORD_OWNERS.keys.map { |type| "destroy.#{type.constantize.table_name.singularize}" }.uniq
    end

    def owner_conditions(type, column, owner_types, owners)
      return [ owner_condition(type, column, owners[owner_types]) ].compact if owner_types.is_a?(String)

      owners.slice(*owner_types).map do |polymorphic_type, ids|
        type_match = Ahoy::Event.sanitize_sql_array(
          [ "JSON_UNQUOTE(JSON_EXTRACT(ahoy_events.properties, ?)) = ?", "$.attributes.#{column}_type", polymorphic_type ]
        )
        "(#{owner_condition(type, "#{column}_id", ids)} AND #{type_match})"
      end
    end

    def owner_condition(type, column, ids)
      return nil if ids.blank?

      Ahoy::Event.sanitize_sql_array(
        [ "(ahoy_events.resource_type = ? AND CAST(JSON_EXTRACT(ahoy_events.properties, ?) AS UNSIGNED) IN (?))",
          type, "$.attributes.#{column}", ids.to_a ]
      )
    end

    def comment_aggregator
      @comment_aggregator ||= PersonCommentAggregator.new(@person)
    end

    # A deleted comment, or one moved to someone else's record, no longer joins
    # to the person — so it's matched by the parent its delete snapshot or move
    # diff recorded, and its whole history comes along.
    def departed_comment_ids
      commentables = comment_aggregator.commentable_ids_by_type.flat_map { |type, ids| ids.map { |id| [ type, id ] } }
      deleted_parents = deleted_record_ids.flat_map { |type, ids| ids.map { |id| [ owner_key(type), id ] } }
      owned = (commentables + deleted_parents).to_set
      events = departure_events.to_a
      comments = Comment.where(id: events.map(&:resource_id)).index_by(&:id)
      events.filter_map { |event| event.resource_id if former_parents(event, comments[event.resource_id]).intersect?(owned) }.uniq
    end

    def departure_events
      Ahoy::Event.where(resource_type: "Comment")
        .where("ahoy_events.name = 'destroy.comment' OR JSON_CONTAINS_PATH(ahoy_events.properties, 'one', '$.changes.commentable_id')")
        .select(:id, :resource_id, :properties)
    end

    def former_parents(event, comment)
      properties = event.properties || {}
      snapshot = EventReferenceLoader.polymorphic_references(properties["attributes"].to_h).values
      moves = EventReferenceLoader.polymorphic_changes("Comment", properties["changes"], comment).values.flatten(1)
      (snapshot + moves).filter_map { |type, id| [ type.to_s, id.to_i ] if type.present? && id.present? }.to_set
    end

    # resource_type => ids (arrays or id-only subqueries). Mirrors the records in
    # people/_associated_records plus the person's own nested records.
    def resource_ids_by_type
      map = {
        "Person" => [ @person.id ],
        "Affiliation" => @person.affiliations.select(:id),
        "ProfessionalLicense" => @person.professional_licenses.select(:id),
        "Membership" => @person.memberships.select(:id),
        "Address" => @person.addresses.select(:id),
        "ContactMethod" => @person.contact_methods.select(:id),
        # Every comment connected to the person, not just profile comments —
        # reuses PersonCommentAggregator so History and the comments page agree.
        "Comment" => comment_aggregator.comments.reorder(nil).select(:id),
        "EventRegistration" => registration_ids,
        "ContinuingEducationRegistration" => ce_registration_ids,
        "EventRegistrationChecklistCompletion" => EventRegistrationChecklistCompletion.where(event_registration_id: registration_ids).select(:id),
        "EventRegistrationOrganization" => EventRegistrationOrganization.where(event_registration_id: registration_ids).select(:id),
        "EventAttendanceTimeEntry" => EventAttendanceTimeEntry.where(event_registration_id: registration_ids).select(:id),
        "EventStaff" => @person.event_staffs.select(:id),
        "FormSubmission" => submission_ids,
        "FormAnswer" => answer_ids,
        # Uploads only reach a person through the form answer that owns them.
        "Asset" => Asset.where(owner_type: "FormAnswer", owner_id: answer_ids).select(:id),
        "Grant" => @person.grants.select(:id),
        "Payment" => payment_ids,
        "Allocation" => allocation_ids,
        "Refund" => refund_ids,
        "MembershipInvoice" => @person.membership_invoices.select(:id),
        "Scholarship" => scholarship_ids,
        "ScholarshipAgreementResponse" => ScholarshipAgreementResponse.where(scholarship_id: scholarship_ids).select(:id),
        "TopicSubscription" => @person.topic_subscriptions.select(:id),
        "CommunityNews" => @person.community_news_as_author.select(:id),
        "Resource" => @person.resources_as_author.select(:id),
        "Story" => @person.stories_as_author.select(:id),
        "StoryIdea" => StoryIdea.created_by_person(@person.id).select(:id),
        "Workshop" => @person.workshops_as_author.select(:id),
        "WorkshopIdea" => WorkshopIdea.created_by_person(@person.id).select(:id),
        "WorkshopVariation" => @person.workshop_variations_as_author.select(:id),
        "WorkshopVariationIdea" => WorkshopVariationIdea.created_by_person(@person.id).select(:id)
      }
      PAYMENT_SUBCLASSES.each { |type| map[type] = payment_ids }
      if (user = @person.user)
        map["User"] = [ user.id ]
        map["WorkshopLog"] = user.workshop_logs.select(:id)
      end
      map
    end

    def registration_ids
      @registration_ids ||= @person.event_registrations.select(:id)
    end

    def ce_registration_ids
      @ce_registration_ids ||= ContinuingEducationRegistration.where(event_registration_id: registration_ids).select(:id)
    end

    def submission_ids
      @submission_ids ||= @person.form_submissions.select(:id)
    end

    def answer_ids
      @answer_ids ||= FormAnswer.where(form_submission_id: submission_ids).select(:id)
    end

    def payment_ids
      @payment_ids ||= Payment.where(person_id: @person.id).select(:id)
    end

    def scholarship_ids
      @scholarship_ids ||= @person.scholarships.select(:id)
    end

    # An allocation is money moving against something this person owes: their
    # registration, its CE add-on, or a membership invoice.
    def allocation_ids
      Allocation.where(allocatable_type: "EventRegistration", allocatable_id: registration_ids)
        .or(Allocation.where(allocatable_type: "ContinuingEducationRegistration", allocatable_id: ce_registration_ids))
        .or(Allocation.where(allocatable_type: "MembershipInvoice", allocatable_id: @person.membership_invoices.select(:id)))
        .select(:id)
    end

    # Theirs when they receive it, or when it reverses a payment they made.
    def refund_ids
      Refund.where(recipient_type: "Person", recipient_id: @person.id)
        .or(Refund.where(refundable_type: "Payment", refundable_id: payment_ids))
        .select(:id)
    end

    # Auth events store the user under properties.record_id/record_type rather
    # than the resource_type/resource_id columns, so they need a JSON match.
    def auth_scope
      Ahoy::Event
        .where("ahoy_events.name LIKE 'auth.%'")
        .where(
          "CAST(JSON_EXTRACT(ahoy_events.properties, '$.record_id') AS UNSIGNED) = :id AND " \
          "JSON_UNQUOTE(JSON_EXTRACT(ahoy_events.properties, '$.record_type')) = 'User'",
          id: @person.user.id
        )
    end
  end
end
