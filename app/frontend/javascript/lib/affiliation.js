// The single JS source of truth for "is this the standing Facilitator
// affiliation?", mirroring the server's title rule (Affiliation derives its STI
// type from this): the title must be *exactly* "Facilitator" (trimmed,
// case-sensitive). Variants like "Lead Facilitator" or "facilitator" are
// deliberately excluded. The affiliation editors drive their live preview off the
// typed title, so they compare the input value through this helper.
export const facilitatorTitle = "Facilitator"

export const isFacilitatorTitle = (title) => (title ?? "").trim() === facilitatorTitle
