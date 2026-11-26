export const facilitatorType = "facilitator"

export const isFacilitatorType = (type) => type === facilitatorType

// Mirrors Affiliation#zero_length? / .zero_length: a row that starts and ends on the
// same day is a no-show's deactivated stub, not facilitation (ADR-0001 D8a). The org
// form's readings drop these; a person's own facilitator dates keep them.
export const isZeroLength = (affiliation) =>
  Boolean(affiliation.startDate) && Boolean(affiliation.endDate) &&
  new Date(affiliation.endDate).getTime() === new Date(affiliation.startDate).getTime()
