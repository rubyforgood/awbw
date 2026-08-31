module ButtonHelper
  # Single source of truth for button styling, replacing the @apply-based .btn
  # component classes (Evil Martians best practice #4: keep the utilities in the
  # markup via a helper rather than extracting them into @apply CSS). Tailwind
  # scans this file (see the @source in application.tailwind.css), so the class
  # strings below generate exactly like inline utilities.
  BUTTON_BASE = "inline-flex items-center gap-2 font-medium shadow-sm " \
                "transition-colors duration-200 focus:outline-none focus:ring-2 " \
                "focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed".freeze

  # Size sets the padding + text scale. Pass `size: nil` when the call site
  # supplies its own padding/text-size via `extra:` so the two don't collide
  # (conflicting utilities in one class list resolve by Tailwind's generation
  # order, not markup order — unlike the old component/utility layer split).
  BUTTON_SIZES = {
    md: "px-4 py-2 text-sm",
    sm: "px-3 py-1 text-xs"
  }.freeze

  # Shape owns the border-radius so a call site can pick the marketing pill
  # (`shape: :pill`) without splicing a conflicting `rounded-*` into `extra:`.
  # `:default` keeps the standard rounded-lg every existing button already used.
  BUTTON_SHAPES = {
    default: "rounded-lg",
    pill: "rounded-full"
  }.freeze

  BUTTON_VARIANTS = {
    primary: "border border-primary bg-primary text-white hover:bg-white hover:text-primary",
    brand: "bg-brand-yellow-400 text-brand-navy-900 hover:bg-brand-yellow-600",
    brand_raised: "bg-brand-yellow-400 text-brand-navy-900 font-bold border-b-4 border-brand-yellow-600 hover:bg-brand-yellow-500 hover:border-brand-yellow-700",
    accent: "border-2 border-accent bg-accent text-white hover:bg-white hover:text-accent",
    success: "border-2 border-success bg-success text-white hover:bg-white hover:text-success",
    secondary: "border border-secondary bg-secondary text-white hover:bg-white hover:text-secondary",
    info: "border border-info bg-info text-white hover:bg-white hover:text-info",
    warning: "border border-warning bg-warning text-white hover:bg-white hover:text-warning",
    danger: "border border-danger bg-danger text-white hover:bg-white hover:text-danger",
    utility: "border border-gray-200 bg-gray-200 text-gray-800 hover:bg-white hover:text-gray-600",
    primary_outline: "border border-primary text-primary hover:bg-primary hover:text-white",
    accent_outline: "border-2 border-accent text-accent hover:bg-accent hover:text-white",
    success_outline: "border-2 border-success text-success hover:bg-success hover:text-white",
    secondary_outline: "border border-secondary text-secondary hover:bg-secondary hover:text-white",
    info_outline: "border border-info text-info hover:bg-info hover:text-white",
    warning_outline: "border border-warning text-warning hover:bg-warning hover:text-white",
    danger_outline: "border border-danger text-danger hover:bg-danger hover:text-white",
    utility_outline: "border border-gray-200 text-gray-600 hover:bg-gray-200 hover:text-gray-800"
  }.freeze

  # `variant`, `size`, and `shape` each take `nil` to opt that layer out and let
  # the call site supply its own: `variant: nil` drops the color (a custom/dynamic
  # fill), `size: nil` drops the padding + text-size, `shape: nil` drops the
  # border-radius (call site sets its own via `extra:` — see BUTTON_SIZES for why
  # they'd otherwise collide). The `if` guards are what make those nils skip the
  # `fetch` instead of raising; base stays the single source of truth either way
  # rather than being inlined.
  def button_classes(variant = :primary, size: :md, shape: :default, extra: nil)
    tokens = [ BUTTON_BASE ]
    tokens << BUTTON_VARIANTS.fetch(variant) if variant
    tokens << BUTTON_SIZES.fetch(size) if size
    tokens << BUTTON_SHAPES.fetch(shape) if shape
    tokens << extra if extra.present?
    tokens.join(" ")
  end

  # The AWBW brand CTA button (marketing "Donate" / "Explore" style): gold fill,
  # navy label, with a raised darker-gold bottom edge that presses on click. The
  # edge comes from the --shadow-brand-cta theme token so it tracks the gold.
  # Register buttons layer on `font-display uppercase` — see BRAND_CTA_REGISTER.
  BRAND_CTA = "inline-flex items-center justify-center gap-2 rounded-lg bg-brand-yellow-400 font-bold text-brand-navy-900 shadow-brand-cta transition hover:bg-brand-yellow-300 active:translate-y-0.5 active:shadow-brand-cta-pressed".freeze
  BRAND_CTA_REGISTER = "font-display tracking-wide uppercase".freeze

  def brand_cta_classes(register: false, extra: nil)
    [ BRAND_CTA, (BRAND_CTA_REGISTER if register), extra ].compact.join(" ")
  end
end
