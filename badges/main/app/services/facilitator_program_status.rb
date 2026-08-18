# The one rule for an organization's New / Ongoing / Reinstated program status,
# judged on its Facilitator affiliations as of an anchor date. Every surface that
# shows the word goes through here, so they can't disagree. See ADR-0001 D4–D7 for
# the rule, the strict-`<` boundary and the anchor.
class FacilitatorProgramStatus
  STATUSES = %i[ new ongoing reinstated ].freeze

  # Reads the already-loaded affiliations, so a page can classify many orgs
  # without an N+1.
  def self.for(organization, as_of: nil)
    new(organization.affiliations, as_of: as_of)
  end

  attr_reader :as_of

  def initialize(affiliations, as_of: nil)
    @as_of = (as_of || Date.current.beginning_of_year).to_date
    @year_anchored = as_of.nil?
    @facilitators = affiliations.select { |affiliation| affiliation.facilitator? && affiliation.start_date }
  end

  # Views that show a year-anchored figure add a caveat saying so.
  def year_anchored? = @year_anchored

  def status
    @status ||= if earlier.empty?
      :new
    elsif active_on_anchor.any?
      :ongoing
    else
      :reinstated
    end
  end

  def label = status.to_s.titleize

  # For :ongoing the most recent start still running on the anchor; for
  # :reinstated the most recent start of the lapsed history. Nil for :new.
  def active_since
    @active_since ||= (active_on_anchor.presence || earlier).filter_map(&:start_date).max
  end

  # When a :reinstated program's history ran out. Nil for the other statuses.
  def lapsed_on
    return nil unless status == :reinstated

    @lapsed_on ||= earlier.filter_map(&:end_date).max
  end

  # The facilitator history behind the verdict, e.g. "Aug 2015 – Jun 2018, Feb 2024".
  def periods_label
    @periods_label ||= AffiliationPeriods.label(@facilitators, today: as_of, precision: :month)
  end

  # Hover text, so every display site explains the figure the same way.
  def explanation
    [ anchor_sentence, reason_sentence, periods_sentence ].compact.join(" ")
  end

  private

  def anchor_sentence
    anchored = year_anchored? ? "start of #{as_of.year} — no event in view" : "event start date"
    "#{label} as of #{as_of.strftime('%b %-d, %Y')} (#{anchored})."
  end

  def reason_sentence
    case status
    when :new then "No facilitator affiliation started before this date."
    when :ongoing then "Active facilitator affiliation since #{month(active_since)}."
    when :reinstated
      ended = lapsed_on ? " through #{month(lapsed_on)}" : ""
      "Previously active from #{month(active_since)}#{ended}, with none active on this date."
    end
  end

  def periods_sentence
    return nil if periods_label.blank?

    "Facilitator periods: #{periods_label}."
  end

  def month(date) = date&.strftime("%b %Y")

  # Strictly before: an affiliation starting ON the anchor is the one this event
  # minted (ADR-0001 D8), so a first-time org still reads New at its own training.
  def earlier
    @earlier ||= @facilitators.select { |affiliation| affiliation.start_date < as_of }
  end

  def active_on_anchor
    @active_on_anchor ||= earlier.select { |affiliation| affiliation.end_date.nil? || affiliation.end_date >= as_of }
  end
end
