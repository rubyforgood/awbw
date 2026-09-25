class PersonPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin? || (Profiles.enabled? && authenticated?)
  end

  def show?
    admin? || owner? || (Profiles.enabled? && authenticated? && record.published?)
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
    admin? || (Profiles.enabled? && owner?)
  end

  def update?
    admin? || (Profiles.enabled? && owner?)
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

  private

  def owner?
    return false unless authenticated?
    record.user == user
  end

  def has_associated_data?
    record.user.present? ||
      record.affiliations.exists? ||
      record.stories_as_spotlighted_facilitator.exists? ||
      record.stories_as_author.exists? ||
      record.workshop_variations_as_author.exists? ||
      record.workshops_as_author.exists? ||
      record.community_news_as_author.exists? ||
      record.resources_as_author.exists?
  end
end
