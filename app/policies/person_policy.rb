class PersonPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  # email_2 is matched as an identity (PersonMatcher, duplicate finders), so only admins set it.
  ADMIN_ONLY_FIELDS = %i[
    email email_2 email_2_type
    filemaker_code blog_contributor notes member_since
    created_by_id updated_by_id
    staff_taggings_attributes affiliations_attributes comments_attributes
    notifications_attributes user_attributes
  ].freeze

  OWNER_USER_FIELDS = %i[time_zone].freeze

  # People-index filters only an admin may apply. The index itself is readable by
  # any signed-in user while profiles preview, but each of these narrows the list
  # by internal data — so a non-admin passing one by URL would learn which people
  # carry an admin-only staff tag or subscription. The filter bar renders them
  # behind the same admin gate the :index params_filter enforces.
  ADMIN_ONLY_FILTERS = %i[
    role facilitator_status membership_status
    staff_tag_ids topic_subscription_type_id
  ].freeze

  def index?
    admin? || profiles_visible_to_users?
  end

  def show?
    admin? || owner? || (profiles_visible_to_users? && record.published?)
  end

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

  params_filter(:index) do |params|
    next params if admin?
    params.except(*ADMIN_ONLY_FILTERS)
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

    owner_params = permitted.except(*ADMIN_ONLY_FIELDS)
    owner_user_params = permitted[:user_attributes]&.slice(*OWNER_USER_FIELDS)
    owner_params[:user_attributes] = owner_user_params if owner_user_params.present?
    owner_params
  end

  private

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
