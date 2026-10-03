class PersonPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  # Fields a non-admin owner may NOT change about their own profile once profiles
  # are enabled — privilege- or admin-only data the self-edit form doesn't expose.
  # Everything else is owner-editable, so add any new admin-only person attribute
  # here. (professional_licenses_attributes stays owner-editable: the controller's
  # reject_locked_license_changes! is the per-license backstop that blocks CE-tied ones.)
  ADMIN_ONLY_FIELDS = %i[
    email email_type email_2 email_2_type
    filemaker_code blog_contributor notes member_since
    created_by_id updated_by_id
    staff_taggings_attributes affiliations_attributes comments_attributes
    notifications_attributes user_attributes
  ].freeze

  def index?
    admin? || profiles_visible_to_users?
  end

  def show?
    admin? || owner? || (profiles_visible_to_users? && record.published?)
  end

  # Admin, or the profile's own person. The narrow rule for owner-only content
  # (submitted ideas, workshop logs) — kept separate from `show?` so opening
  # `show?` up to public profile viewing later can't expose it.
  def own_record?
    admin? || owner?
  end

  def workshop_logs?
    admin? || owner?
  end

  def own_membership?
    owner? && Membership.enabled?
  end

  def show_email_change?
    admin? || owner?
  end

  def checkout?
    admin?
  end

  # A person edits their own profile once profiles are enabled; the controller
  # strips admin-only fields from what a non-admin owner can submit.
  def edit?
    admin? || (profiles_visible_to_users? && owner?)
  end

  def update?
    admin? || (profiles_visible_to_users? && owner?)
  end

  def destroy?
    admin? && record.persisted? && !has_associated_data?
  end

  def search?
    admin?
  end

  def send_form_link?
    admin?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.searchable.with_active_facilitator_affiliations.where_user_not_locked
  end

  params_filter do |params|
    permitted = params.permit(
      :avatar,
      :first_name, :legal_first_name, :last_name,
      :email, :email_type,
      :email_2, :email_2_type,
      :street_address, :city, :state, :zip, :country, :mailing_address_type,
      :best_time_to_call,
      :date_of_birth,
      :racial_ethnic_identity,
      :filemaker_code,
      :blog_contributor,
      :bio, :shoutout_text, :notes,
      :display_name_preference,
      :anonymous_contributions,
      :pronunciation,
      :pronouns,
      :profile_is_searchable,
      :profile_show_pronouns,
      :profile_show_credentials,
      :profile_show_bio,
      :profile_show_email,
      :profile_show_phone,
      :profile_show_member_since,
      :profile_show_sectors,
      :profile_show_age_ranges,
      :profile_show_affiliations,
      :profile_show_social_media,
      :profile_show_events_registered,
      :profile_show_stories,
      :profile_show_story_ideas,
      :profile_show_workshop_variations,
      :profile_show_workshop_variation_ideas,
      :profile_show_workshops,
      :profile_show_workshop_ideas,
      :profile_show_workshop_logs,
      :profile_show_monthly_reports,
      :profile_show_resources,
      :member_since,
      :linked_in_url,
      :facebook_url,
      :instagram_url,
      :youtube_url,
      :twitter_url,
      :created_by_id, :updated_by_id,
      sectorable_items_attributes: [ :id, :sector_id, :is_leader, :is_primary, :_destroy ],
      staff_taggings_attributes: [ :id, :staff_tag_id, :_destroy ],
      age_range_categorizable_items_attributes: [ :id, :category_id, :is_primary, :_destroy ],
      addresses_attributes: [
        :id,
        :address_type,
        :primary,
        :street_address,
        :city,
        :state,
        :zip_code,
        :country,
        :county,
        :district,
        :locality,
        :phone,
        :inactive,
        :_destroy
      ],
      contact_methods_attributes: [
        :id,
        :address_id,
        :contactable_id,
        :contactable_type,
        :contact_type,
        :kind,
        :value,
        :primary,
        :inactive,
        :_destroy
      ],
      user_attributes: [
        :id, :person_id,
        :first_name,
        :last_name,
        :email,
        :birthday,
        :inactive,
        :super_user,
        :phone,
        :phone2,
        :phone3,
        :best_time_to_call,
        :address,
        :city,
        :state,
        :zip,
        :address2,
        :city2,
        :state2,
        :zip2,
        :notes,
        :time_zone
      ],
      affiliations_attributes: [
        :id,
        :organization_id,
        :title,
        :inactive,
        :inactive_supplied,
        :primary_contact,
        :start_date,
        :end_date,
        :organization_address_id,
        :_destroy
      ],
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: Notification::PERMITTED_LOG_ATTRIBUTES,
      professional_licenses_attributes: [ :id, :number, :kind, :issuing_state, :expires_on, :_destroy ]
    )
    next permitted if admin?

    permitted.except(*ADMIN_ONLY_FIELDS)
  end

  private

  # Temporary launch gate: signed-in users preview profiles everywhere but
  # production, where they stay off until launch. Admins always have access; the
  # public never does. Remove this method at launch (access becomes unconditional
  # for signed-in users); it mirrors OrganizationPolicy's copy in #2563.
  def profiles_visible_to_users?
    authenticated? && !Rails.env.production?
  end

  def owner?
    return false unless authenticated?
    record.user == user
  end

  def has_associated_data?
    record.user.present? ||
      record.affiliations.exists? ||
      record.stories_as_spotlighted_facilitator.exists? ||
      record.stories_as_author.exists? ||
      record.stories_as_co_author.exists? ||
      record.workshop_variations_as_author.exists? ||
      record.workshops_as_author.exists? ||
      record.community_news_as_author.exists? ||
      record.resources_as_author.exists?
  end
end
