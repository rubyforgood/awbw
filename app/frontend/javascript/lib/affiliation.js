// Single JS source of the facilitator rule, mirroring Affiliation#facilitator? /
// .facilitators: the title must be exactly "Facilitator" (trimmed, case-sensitive).
// The affiliation editors drive their live preview off the typed title through this.
export const facilitatorTitle = "Facilitator"

export const isFacilitatorTitle = (title) => (title ?? "").trim() === facilitatorTitle
