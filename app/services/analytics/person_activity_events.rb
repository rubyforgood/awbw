module Analytics
  # Collects every Ahoy event that belongs to a person's history: events about
  # the person record itself, about their user account (both lifecycle and
  # `auth.*` events), and about the associated records surfaced on the person's
  # "Associated records" panel. Powers the person edit "History" card and the
  # `person_id` filter on the admin Ahoy activities index.
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
        "EventRegistration" => @person.event_registrations.select(:id),
        "ContinuingEducationRegistration" => ContinuingEducationRegistration.where(event_registration_id: @person.event_registrations.select(:id)).select(:id),
        "FormSubmission" => @person.form_submissions.select(:id),
        "Grant" => @person.grants.select(:id),
        "Payment" => Payment.where(person_id: @person.id).select(:id),
        "Scholarship" => @person.scholarships.select(:id),
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
      # Notifications match the person by recipient email — mirrors the panel's
      # "Communications (universal)" card, which now emits events (see AhoyTrackable).
      if (email = @person.preferred_email).present?
        map["Notification"] = Notification.email(email).select(:id)
      end
      map
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
