# Deletes a set of people along with ALL of their associated data, their linked
# User account and the user's own data (where relevant), and the audit trail for
# everything removed. Backs both the data:remove_people rake task and
# the admin-only "Delete person & all data" button on the person edit page.
#
# Person.destroy cascades everything a person owns — submissions, answers,
# affiliations, registrations, scholarships, addresses, contact methods,
# bookmarks, comments, sector/category tags, grants, event staffing. This also
# tears down what does NOT cascade off Person: payments (+ their refunds and
# allocations), bulk-payment notifications, Stripe Pay::Customer rows, and the
# PaperTrail + Ahoy audit trail for every record removed.
#
# The linked User and ALL of its own data are removed too: bookmarks, comments,
# user_forms, the user's notifications, Ahoy activity, AND everything it authored
# (workshops, workshop logs, reports, resources, stories, and the various ideas
# and variations). The purge preview lists all of this so the operator sees the
# full blast radius before confirming.
#
# People that look real are SKIPPED, never deleted: a grant donor, a spotlighted
# facilitator, or anyone with a User account — unless delete_users: true AND the
# account is clearly an unused auto-created one (never signed in, not a
# super_user, no Ahoy activity of its own, authored no other people). A real
# admin is always protected.
#
# force: true is a deliberate escape hatch that ignores ALL of the protections
# above and deletes anyway — the account and everything it authored. Records that
# merely *reference* the account without being owned by it (e.g. it created a
# shared banner or event) are FK-restricted; the transaction rolls back and the
# caller surfaces a clear error rather than orphaning or rewriting them.
#
# MAINTENANCE: the deletion graph is partly hardcoded (collected, audit_targets,
# authored_content_scopes, account_content). When an association is added to
# Person/User — or a model starts referencing them (person_id, user_id,
# created_by_id, updated_by_id, polymorphic *able) — wire it in here so purges
# keep cascading/clearing it instead of orphaning or blocking.
# spec/services/people_remover_association_coverage_spec.rb fails when a new
# Person/User association isn't accounted for.
class PeopleRemover
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

  # Everything removed along with the destroyed User account(s) — its authored
  # content plus the records that cascade with it — for the purge preview. Empty
  # when no account is involved.
  def account_content
    user_ids = collected[:users].map(&:id)
    return {} if user_ids.empty?

    counts = authored_content_scopes(user_ids).to_h { |label, relation| [ label, relation.count ] }
    counts["Bookmarks"] = Bookmark.where(user_id: user_ids).count
    counts["User forms"] = UserForm.where(user_id: user_ids).count
    counts["Notifications"] = Notification.where(noticeable_type: "User", noticeable_id: user_ids).count
    counts.select { |_, count| count.positive? }
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

    # The destroys below buffer Ahoy "destroy" lifecycle events (the who/what/when
    # deletion audit), but the buffer is flushed after the request — outside this
    # transaction. Remember its size so a rollback can drop the events this purge
    # added; otherwise the controller flushes phantom destroys for records that
    # still exist.
    buffered_lifecycle_events = Analytics::LifecycleBuffer.store.size
    c = collected
    user_ids = c[:users].map(&:id)
    ActiveRecord::Base.transaction do
      # Detach the user<->person link first. update_column bypasses the User
      # validation that forbids nulling person_id and makes Person's has_one :user
      # nullify a no-op — so we can delete the person before the user (next), even
      # though the person references the user via created_by/updated_by.
      c[:users].each { |user| user.update_column(:person_id, nil) }
      deletable.each { |person| person.association(:user).reset }

      # Non-cascading person records, FK-safe order: allocations and refunds
      # reference payments; payments reference submissions.
      Allocation.where(id: c[:allocation_ids]).find_each(&:destroy!)
      Refund.where(id: c[:refund_ids]).find_each(&:destroy!)
      Payment.where(id: c[:payment_ids]).find_each(&:destroy!)
      Notification.where(id: c[:notification_ids]).find_each(&:destroy!)
      Pay::Customer.where(id: c[:pay_customer_ids]).find_each(&:destroy!)

      # Everything the account authored (FK-restricted, leaf → root) plus its own
      # notifications — these don't cascade off the user and would block it.
      authored_content_scopes(user_ids).each { |_, relation| relation.find_each(&:destroy!) }
      Notification.where(noticeable_type: "User", noticeable_id: user_ids).delete_all

      # People BEFORE users: destroying a person removes its created_by/updated_by
      # and affiliations (all FK to users), so the account is unreferenced by the
      # time it's destroyed.
      deletable.each(&:destroy!)
      c[:users].each(&:destroy!)

      delete_audit_trail(c)
    end

    deletable.map(&:id)
  rescue
    # Roll back the lifecycle events this purge buffered so a failed delete can't
    # leave phantom Ahoy "destroy" records for records that still exist.
    Analytics::LifecycleBuffer.store.slice!(buffered_lifecycle_events..)
    raise
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

  # Content authored by the account(s), as [label, relation] in FK-safe delete
  # order (leaf → root). created_by_id-owned with no dependent, so it must be
  # destroyed explicitly before the account or its FKs block the deletion.
  def authored_content_scopes(user_ids)
    [
      [ "Comments", Comment.where(created_by_id: user_ids) ],
      [ "Story ideas", StoryIdea.where(created_by_id: user_ids) ],
      [ "Workshop ideas", WorkshopIdea.where(created_by_id: user_ids) ],
      [ "Workshop variation ideas", WorkshopVariationIdea.where(created_by_id: user_ids) ],
      [ "Workshop variations", WorkshopVariation.where(created_by_id: user_ids) ],
      [ "Workshop logs", WorkshopLog.where(created_by_id: user_ids) ],
      [ "Stories", Story.where(created_by_id: user_ids) ],
      [ "Workshops", Workshop.where(created_by_id: user_ids) ],
      [ "Reports", Report.where(created_by_id: user_ids) ],
      [ "Resources", Resource.where(created_by_id: user_ids) ]
    ]
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
