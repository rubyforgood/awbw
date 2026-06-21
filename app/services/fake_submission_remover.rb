# Deletes a set of people along with their entire data graph and audit trail.
# Built for cleaning up FAKE form submissions (hence the name and the protections
# below), but the mechanism is general — it backs both the
# data:remove_fake_submissions rake task and the admin-only "Delete person & all
# data" button on the person edit page. When general person-deletion grows beyond
# the fake-data use case, rename this to something like PersonPurger.
#
# Person.destroy cascades the submissions, answers, affiliations, registrations
# and scholarships (see Person). This also tears down what does NOT cascade:
# payments (+ their refunds and allocations), bulk-payment notifications, Stripe
# Pay::Customer rows, and the PaperTrail + Ahoy audit trail for every record
# removed.
#
# People that look real are SKIPPED, never deleted: a grant donor, a spotlighted
# facilitator, or anyone with a User account — unless delete_users: true AND the
# account is clearly an unused auto-created one (never signed in, not a
# super_user, no Ahoy activity of its own, authored no other people). A real
# admin is always protected. This is ONLY for fake data — never use it to delete
# a regular person.
#
# force: true is a deliberate escape hatch that ignores ALL of the protections
# above and deletes anyway (destroying any linked account). Use only when you are
# certain the heuristic is a false positive. The database still refuses to orphan
# real authored content (workshops, reports, stories are FK-restricted), so a
# force delete of an account that authored content fails and rolls back.
class FakeSubmissionRemover
  Skip = Data.define(:person, :reasons)

  # Only these models carry has_paper_trail.
  VERSIONED_TYPES = %w[Payment Refund Allocation].freeze

  def initialize(person_ids: [], form_submission_ids: [], delete_users: false, force: false)
    @person_ids = Array(person_ids).map(&:to_i).uniq
    @form_submission_ids = Array(form_submission_ids).map(&:to_i).uniq
    @delete_users = delete_users
    @force = force
  end

  # Why a person is protected, independent of delete_users/force — for showing
  # the operator what they'd be overriding. Empty means the person is safe.
  def protection_reasons(person)
    reasons = []
    reasons << account_description(person.user) if person.user.present?
    reasons << "is a spotlighted facilitator" if person.stories_as_spotlighted_facilitator.exists?
    reasons << "is a grant donor" if person.grants.exists?
    reasons
  end

  # People that will be deleted (passed every safety check).
  def deletable
    @deletable ||= people.select { |person| reasons_for(person).empty? }
  end

  # People that look real, with the reason(s) they were skipped.
  def skipped
    @skipped ||= people.filter_map do |person|
      reasons = reasons_for(person)
      Skip.new(person: person, reasons: reasons) if reasons.any?
    end
  end

  def missing_person_ids
    target_person_ids - people.map(&:id)
  end

  def missing_form_submission_ids
    @form_submission_ids - FormSubmission.where(id: @form_submission_ids).pluck(:id)
  end

  # Content authored by the User account(s) that would be destroyed in a force
  # delete and which the database REFUSES to orphan (created_by_id is FK-restricted
  # with no dependent). If any of these exist the delete cannot proceed — the
  # content must be reassigned or removed first.
  def blocking_account_content
    user_ids = collected[:users].map(&:id)
    return {} if user_ids.empty?

    {
      "Workshops" => Workshop.where(created_by_id: user_ids).count,
      "Workshop logs" => WorkshopLog.where(created_by_id: user_ids).count,
      "Workshop ideas" => WorkshopIdea.where(created_by_id: user_ids).count,
      "Workshop variations" => WorkshopVariation.where(created_by_id: user_ids).count,
      "Workshop variation ideas" => WorkshopVariationIdea.where(created_by_id: user_ids).count,
      "Reports" => Report.where(created_by_id: user_ids).count,
      "Resources" => Resource.where(created_by_id: user_ids).count,
      "Stories" => Story.where(created_by_id: user_ids).count,
      "Story ideas" => StoryIdea.where(created_by_id: user_ids).count,
      "Comments" => Comment.where(created_by_id: user_ids).count
    }.select { |_, count| count.positive? }
  end

  # Records owned by the User account that ARE removed with it (dependent: destroy).
  def cascading_account_content
    user_ids = collected[:users].map(&:id)
    return {} if user_ids.empty?

    {
      "Bookmarks" => Bookmark.where(user_id: user_ids).count,
      "User forms" => UserForm.where(user_id: user_ids).count
    }.select { |_, count| count.positive? }
  end

  # Per-record-type counts for a dry-run preview. Does not mutate anything.
  def counts
    c = collected
    {
      people: deletable.size,
      users: c[:users].size,
      form_submissions: c[:submission_ids].size,
      form_answers: c[:answer_ids].size,
      affiliations: c[:affiliation_ids].size,
      event_registrations: c[:registration_ids].size,
      scholarships: c[:scholarship_ids].size,
      payments: c[:payment_ids].size,
      refunds: c[:refund_ids].size,
      allocations: c[:allocation_ids].size,
      notifications: c[:notification_ids].size,
      pay_customers: c[:pay_customer_ids].size,
      paper_trail_versions: version_count,
      ahoy_events: ahoy_count
    }
  end

  # Deletes the graph in a single transaction. Returns the ids of the deleted
  # people (empty when nothing was safe to delete).
  def call
    return [] if deletable.empty?

    c = collected
    ActiveRecord::Base.transaction do
      # Non-cascading records first, in FK-safe order: allocations and refunds
      # reference payments; payments reference submissions; everything else
      # cascades off Person. Users are destroyed before their person so the
      # has_one :user nullify (which the model forbids) never runs.
      Allocation.where(id: c[:allocation_ids]).find_each(&:destroy!)
      Refund.where(id: c[:refund_ids]).find_each(&:destroy!)
      Payment.where(id: c[:payment_ids]).find_each(&:destroy!)
      Notification.where(id: c[:notification_ids]).find_each(&:destroy!)
      Pay::Customer.where(id: c[:pay_customer_ids]).find_each(&:destroy!)
      c[:users].each(&:destroy!)
      deletable.each { |person| person.association(:user).reset }
      deletable.each(&:destroy!)
      delete_audit_trail(c)
    end

    deletable.map(&:id)
  end

  private

  attr_reader :delete_users, :force

  def target_person_ids
    @target_person_ids ||= begin
      derived = FormSubmission.where(id: @form_submission_ids).distinct.pluck(:person_id)
      (@person_ids + derived).uniq
    end
  end

  def people
    @people ||= Person.where(id: target_person_ids).to_a
  end

  def reasons_for(person)
    return [] if force

    reasons = []
    if person.user.present? && (real_user?(person.user) || !delete_users)
      reasons << account_description(person.user)
    end
    reasons << "is a spotlighted facilitator" if person.stories_as_spotlighted_facilitator.exists?
    reasons << "is a grant donor" if person.grants.exists?
    reasons
  end

  def account_description(user)
    if real_user?(user)
      "has an active/admin User account (signed in, super_user, or has its own activity)"
    else
      "has a User account"
    end
  end

  # A User is real (and must never be deleted) if it has ever signed in, is a
  # super_user, has Ahoy activity of its own, or authored other people. This runs
  # before any deletion, so cleaning the fake graph can't erase the signal.
  def real_user?(user)
    user.super_user? ||
      user.sign_in_count.to_i.positive? ||
      user.current_sign_in_at.present? || user.last_sign_in_at.present? ||
      Ahoy::Event.where(user_id: user.id).exists? ||
      Person.where(created_by_id: user.id).where.not(id: target_person_ids).exists? ||
      Person.where(updated_by_id: user.id).where.not(id: target_person_ids).exists?
  end

  def collected
    @collected ||= begin
      person_ids = deletable.map(&:id)
      submission_ids = FormSubmission.where(person_id: person_ids).pluck(:id)
      registration_ids = EventRegistration.where(registrant_id: person_ids).pluck(:id)
      scholarship_ids = Scholarship.where(recipient_id: person_ids).pluck(:id)
      payment_ids = Payment.where(person_id: person_ids)
                           .or(Payment.where(form_submission_id: submission_ids)).pluck(:id)
      {
        person_ids: person_ids,
        submission_ids: submission_ids,
        registration_ids: registration_ids,
        scholarship_ids: scholarship_ids,
        affiliation_ids: Affiliation.where(person_id: person_ids).pluck(:id),
        answer_ids: FormAnswer.where(form_submission_id: submission_ids).pluck(:id),
        ero_ids: EventRegistrationOrganization.where(event_registration_id: registration_ids).pluck(:id),
        address_ids: Address.where(addressable_type: "Person", addressable_id: person_ids).pluck(:id),
        contact_method_ids: ContactMethod.where(contactable_type: "Person", contactable_id: person_ids).pluck(:id),
        sectorable_item_ids: SectorableItem.where(sectorable_type: "Person", sectorable_id: person_ids).pluck(:id),
        categorizable_item_ids: CategorizableItem.where(categorizable_type: "Person", categorizable_id: person_ids).pluck(:id),
        payment_ids: payment_ids,
        refund_ids: Refund.where(refundable_type: "Payment", refundable_id: payment_ids).pluck(:id),
        allocation_ids: allocation_ids(payment_ids, scholarship_ids, registration_ids),
        notification_ids: Notification.where(noticeable_type: "FormSubmission", noticeable_id: submission_ids).pluck(:id),
        pay_customer_ids: Pay::Customer.where(owner_type: "Person", owner_id: person_ids).pluck(:id),
        users: (delete_users || force) ? deletable.filter_map(&:user) : []
      }
    end
  end

  def allocation_ids(payment_ids, scholarship_ids, registration_ids)
    Allocation
      .where(source_type: "Payment", source_id: payment_ids)
      .or(Allocation.where(source_type: "Scholarship", source_id: scholarship_ids))
      .or(Allocation.where(allocatable_type: "EventRegistration", allocatable_id: registration_ids))
      .pluck(:id)
  end

  # resource_type => ids, covering every record this task removes — for the Ahoy
  # event and PaperTrail version cleanup.
  def audit_targets(c)
    {
      "Person" => c[:person_ids],
      "FormSubmission" => c[:submission_ids],
      "FormAnswer" => c[:answer_ids],
      "Affiliation" => c[:affiliation_ids],
      "EventRegistration" => c[:registration_ids],
      "EventRegistrationOrganization" => c[:ero_ids],
      "Scholarship" => c[:scholarship_ids],
      "Address" => c[:address_ids],
      "ContactMethod" => c[:contact_method_ids],
      "SectorableItem" => c[:sectorable_item_ids],
      "CategorizableItem" => c[:categorizable_item_ids],
      "Payment" => c[:payment_ids],
      "Refund" => c[:refund_ids],
      "Allocation" => c[:allocation_ids],
      "User" => c[:users].map(&:id)
    }.reject { |_, ids| ids.empty? }
  end

  def delete_audit_trail(c)
    targets = audit_targets(c)

    # Includes the destroy-event versions PaperTrail just wrote for the
    # versioned models.
    targets.slice(*VERSIONED_TYPES).each do |type, ids|
      PaperTrail::Version.where(item_type: type, item_id: ids).delete_all
    end
    targets.each do |type, ids|
      Ahoy::Event.where(resource_type: type, resource_id: ids).delete_all
    end

    user_ids = c[:users].map(&:id)
    return if user_ids.empty?

    Ahoy::Event.where(user_id: user_ids).delete_all
    Ahoy::Visit.where(user_id: user_ids).delete_all
  end

  def version_count
    audit_targets(collected).slice(*VERSIONED_TYPES)
                            .sum { |type, ids| PaperTrail::Version.where(item_type: type, item_id: ids).count }
  end

  def ahoy_count
    resource = audit_targets(collected)
                 .sum { |type, ids| Ahoy::Event.where(resource_type: type, resource_id: ids).count }
    user_ids = collected[:users].map(&:id)
    actor = user_ids.any? ? Ahoy::Event.where(user_id: user_ids).count : 0
    resource + actor
  end
end
