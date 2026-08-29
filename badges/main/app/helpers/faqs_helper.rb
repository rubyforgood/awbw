module FaqsHelper
  # FAQs render in public-facing mode by default. Admins opt into the edit/reorder
  # controls with ?admin=1 (the "Admin mode" link next to the New button).
  def faq_admin_mode?
    allowed_to?(:manage?, Faq) && params[:admin].present?
  end
end
