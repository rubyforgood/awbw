module DataHealth
  # Free-text "Other" answers nobody has promoted, kept, or dismissed yet. The
  # Other responses page is where they're decided, grouped by matching text.
  class PendingOtherResponses < Check
    def title = "\"Other\" answers waiting for review"

    def explanation
      "Someone typed their own answer instead of picking from the list. Promote a sector answer " \
      "to a real sector, keep it as-is, or dismiss it."
    end

    def scope = OtherResponse.pending.includes(:owner).order(created_at: :desc)

    def describe(response)
      "“#{response.text}” — #{response.kind.humanize.downcase} for #{response.owner.try(:name)}"
    end

    def path_for(response) = other_responses_path(status: "pending", anchor: response.review_anchor)

    def review_path = other_responses_path(status: "pending")

    def review_label = "Other responses"
  end
end
