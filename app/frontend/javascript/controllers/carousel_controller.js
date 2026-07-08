import { Controller } from "@hotwired/stimulus"
import Swiper from 'swiper'
import { Navigation } from 'swiper/modules'

import 'swiper/css'
import 'swiper/css/navigation'

// Connects to data-controller="carousel"
// Pass Swiper overrides via data-carousel-options-value='{ "slidesPerView": 2, ... }'.
// Any keys provided there win over the defaults below (breakpoints replace wholesale).
export default class extends Controller {
  static values = { options: Object }

  connect() {
    const defaults = {
      modules: [Navigation],
      loop: true,
      speed: 1400,
      spaceBetween: 30,

      breakpoints: {
        320: {
          slidesPerView: 1,
        },
        485: {
          slidesPerView: 2,
        },
        768: {
          slidesPerView: 3,
        },
        1024: {
          slidesPerView: 4,
        }
      },

      navigation: {
        nextEl: '.swiper-button-next-custom',
        prevEl: '.swiper-button-prev-custom',
      }
    }

    this.swiper = new Swiper(this.element, { ...defaults, ...this.optionsValue })
  }

  disconnect() {
    if (this.swiper) {
      this.swiper.destroy()
    }
  }
}
