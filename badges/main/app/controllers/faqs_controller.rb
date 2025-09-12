class FaqsController < ApplicationController
  def index
    @faqs = Faq.active.by_order
  end
end
