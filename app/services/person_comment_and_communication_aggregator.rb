# Merges the two feeds — every comment connected to a person (via
# PersonCommentAggregator) and every communication addressed to any of their
# email addresses (Person#communications_scope) — into one newest-first list for
# the "Comments & communications" page. With no person, the feed spans
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

  # Newest first, comments and communications interleaved. Loads the full merged
  # set — fine for one person's feed and used in tests; the controller paginates
  # instead (see #paginate).
  def entries
    @entries ||= (comments + communications).sort_by(&:created_at).reverse
  end

  # One page of the interleaved feed without materializing the whole set. Both
  # sides are already newest-first, so the top `page * per_page` of the union can
  # only be drawn from the top that-many of either side — we read no more than
  # that from each, merge, and slice. Keeps the everyone feed from loading every
  # comment and communication just to show twenty.
  def paginate(page_num, per_page)
    page_num = [ page_num.to_i, 1 ].max
    upper = page_num * per_page
    merged = (comment_scope.limit(upper).to_a + communication_scope.limit(upper).to_a)
      .sort_by(&:created_at).reverse
    window = merged[((page_num - 1) * per_page), per_page] || []
    WillPaginate::Collection.create(page_num, per_page, filtered_count) do |pager|
      pager.replace(window)
    end
  end

  def comments
    @comments ||= comment_scope.to_a
  end

  def communications
    @communications ||= communication_scope.to_a
  end

  # Unfiltered totals, so the header can show "12 of 40".
  def total_count
    @total_count ||= comment_base.count + communication_base.count
  end

  # How many entries match the current filters — the "12" in "12 of 40". Counted
  # in SQL so the everyone feed doesn't load rows to size the result.
  def filtered_count
    @filtered_count ||= comment_scope.count + communication_scope.count
  end

  def flagged_count
    @flagged_count ||= comment_base.flagged.count
  end

  private

  def comment_scope
    @comment_scope ||= include_comments? ? comment_base.search_by_params(@params) : Comment.none
  end

  def communication_scope
    @communication_scope ||= include_communications? ? communication_base.search_by_params(@params) : Notification.none
  end

  def comment_base
    @comment_base ||= if @person
      PersonCommentAggregator.new(@person).comments
    else
      Comment.includes(:commentable, :created_by, :updated_by).newest_first
    end
  end

  # Ordered newest-first so #paginate can bound each side with a LIMIT.
  def communication_base
    @communication_base ||= communications_relation.includes(:noticeable, sender: :person).order(created_at: :desc)
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
