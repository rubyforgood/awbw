class PersonPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  # Which tier each field sits in: docs/adr/0006-person-profile-field-access.md
  ADMIN_ONLY_FIELDS = %i[
    email email_2
    filemaker_code blog_contributor notes member_since racial_ethnic_identity
    created_by_id updated_by_id
    staff_taggings_attributes affiliations_attributes comments_attributes
    notifications_attributes
  ].freeze

  ADMIN_ONLY_USER_FIELDS = %i[person_id email inactive super_user notes].freeze
  ADMIN_ONLY_SECTOR_FIELDS = %i[is_leader].freeze
  # Owners can pick which of an organization's addresses is their work address on an
  # affiliation they already have. Everything else about an affiliation goes through a change request.
  OWNER_AFFILIATION_FIELDS = %i[id organization_address_id].freeze

  # People-index filters only an admin may apply. The index itself is readable by
  # any signed-in user while profiles preview, but each of these narrows the list
  # by internal data — so a non-admin passing one by URL would learn which people
  # carry an admin-only staff tag or subscription. The filter bar renders them
  # behind the same admin gate the :index params_filter enforces.
  ADMIN_ONLY_FILTERS = %i[
    role facilitator_status membership_status
    staff_tag_ids topic_subscription_type_id
  ].freeze

  SHARED_ONLY_FILTERS = {
    contact_info: :shared_contact_info,
    sector_ids: :shared_sector_ids,
    age_range_ids: :shared_age_range_ids,
    organization_name: :shared_organization_name,
    organization_id: :shared_organization_id
  }.freeze

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

  def visibility?
    edit?
  end

  def edit_own_profile?
    profiles_visible_to_users? && owner?
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

  # A non-admin's search and filters match only what each profile shares.
  params_filter(:index) do |params|
    next params if admin?
    filters = params.except(*ADMIN_ONLY_FILTERS, *SHARED_ONLY_FILTERS.keys)
    SHARED_ONLY_FILTERS.each { |filter, shared_filter| filters[shared_filter] = params[filter] if params[filter].present? }
    filters
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
      :profile_show_workshop_variations,
      :profile_show_workshops,
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
    owner_params[:user_attributes] = owner_params[:user_attributes].except(*ADMIN_ONLY_USER_FIELDS) if owner_params[:user_attributes]
    owner_params[:sectorable_items_attributes] = without_admin_sector_flags(owner_params[:sectorable_items_attributes]) if owner_params[:sectorable_items_attributes]
    owner_params[:affiliations_attributes] = owner_affiliation_fields(permitted[:affiliations_attributes]) if permitted[:affiliations_attributes]
    owner_params
  end

  private

  def without_admin_sector_flags(items)
    return items.map { |item| item.except(*ADMIN_ONLY_SECTOR_FIELDS) } if items.is_a?(Array)

    items.transform_values { |item| item.except(*ADMIN_ONLY_SECTOR_FIELDS) }
  end

  # Only existing rows (with an id) — an owner can't create an affiliation this way.
  def owner_affiliation_fields(items)
    narrow = ->(item) { item.slice(*OWNER_AFFILIATION_FIELDS) if item[:id].present? }
    return items.filter_map(&narrow) if items.is_a?(Array)

    items.transform_values(&narrow).reject { |_key, item| item.nil? }
  end

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
