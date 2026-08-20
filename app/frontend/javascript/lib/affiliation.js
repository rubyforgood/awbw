// Mirrors the server's facilitator rule (exactly "Facilitator", trimmed,
// case-sensitive) so the editors' live preview matches the persisted STI type.
export const facilitatorTitle = "Facilitator"

export const isFacilitatorTitle = (title) => (title ?? "").trim() === facilitatorTitle
