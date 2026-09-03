# Merges the two feeds — every comment connected to a person (via
# PersonCommentAggregator) and every communication addressed to any of their
# email addresses (Person#communications_scope) — into one newest-first list for
# the "All comments & communications" page. With no person, the feed spans
# everyone: every comment and every communication, filterable the same way.
#
# Both sides keep their own filters (Comment.search_by_params /
# Notification.search_by_params). Most filter params are deliberately shared —
# the two models name the same idea differently, so each side answers on its own
# column: author/from (created_by|updated_by / sender or the incoming contact),
# subject (topic / email_subject), attached-to (commentable_type /
# noticeable_type), and follow-up (flagged / responded). Email topic is the one
# filter only a communication can answer, and `kind` narrows to one side outright.
class PersonCommentAndCommunicationAggregator
  COMMENT_KIND = "comments".freeze
  COMMUNICATION_KIND = "communications".freeze
  KINDS = [ COMMENT_KIND, COMMUNICATION_KIND ].freeze

  # The only filter the comment side cannot answer — a canned email-subject phrase.
  COMMUNICATION_ONLY_PARAMS = %i[email_topic].freeze

  def initialize(person, params = {})
    @person = person
    normalized = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h.symbolize_keys : params.to_h.symbolize_keys
    # person_id selects the scope (a person's feed vs. everyone), not a filter —
    # keep it away from Comment.search_by_params, which would re-scope by it.
    @params = normalized.except(:person_id)
  end

  # Newest first, comments and communications interleaved.
  def entries
    @entries ||= (comments + communications).sort_by(&:created_at).reverse
  end

  def comments
    @comments ||= include_comments? ? comment_base.search_by_params(@params).to_a : []
  end

  def communications
    @communications ||= include_communications? ? communication_base.search_by_params(@params).to_a : []
  end

  # Unfiltered totals, so the header can show "12 of 40".
  def total_count
    @total_count ||= comment_base.count + communication_base.count
  end

  def flagged_count
    @flagged_count ||= comments.count(&:flagged?)
  end

  private

  def comment_base
    @comment_base ||= if @person
      PersonCommentAggregator.new(@person).comments
    else
      Comment.includes(:commentable, :created_by, :updated_by).newest_first
    end
  end

  def communication_base
    @communication_base ||= communications_relation.includes(:noticeable, sender: :person)
  end

  def communications_relation
    @person ? @person.communications_scope : Notification.all
  end

  def include_comments?
    kind != COMMUNICATION_KIND && !any_param?(COMMUNICATION_ONLY_PARAMS)
  end

  def include_communications?
    kind != COMMENT_KIND
  end

  def kind
    KINDS.include?(@params[:kind]) ? @params[:kind] : nil
  end

  def any_param?(keys)
    keys.any? { |key| @params[key].present? }
  end
end
