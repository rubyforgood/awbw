module Analytics
  # Collects every Ahoy event that belongs to a person's history: events about
  # the person record itself, about their user account (both lifecycle and
  # `auth.*` events), and about the associated records surfaced on the person's
  # "Associated records" panel — plus the records that only reach a person
  # through a parent (registration children, the money ledger, form answers and
  # their uploads, agreement responses). Powers the person edit "History" card
  # and the `person_id` filter on the admin Ahoy activities index.
  class PersonActivityEvents
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
      resource_ids_by_type.map do |type, ids|
        Ahoy::Event.where(resource_type: type, resource_id: ids)
      end
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
        "Comment" => PersonCommentAggregator.new(@person).comments.reorder(nil).select(:id),
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
