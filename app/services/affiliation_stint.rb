# One affiliation's stretch of time, for telling a person's separate stints at one
# organization apart. A blank start reads as "since whenever" and a blank end as "still
# going" — except an ended row with no end date, which reads as the moment it started, so
# it can't reach a later stretch.
AffiliationStint = Data.define(:starts, :ends) do
  def self.for(start_date:, end_date:, ended:)
    new(starts: start_date, ends: end_date || (start_date if ended))
  end

  def self.of(affiliation)
    self.for(start_date: affiliation.start_date, end_date: affiliation.end_date, ended: affiliation.inactive?)
  end

  def overlap?(other)
    (starts.nil? || other.ends.nil? || starts <= other.ends) && (other.starts.nil? || ends.nil? || other.starts <= ends)
  end
end
