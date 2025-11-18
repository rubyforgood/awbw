import { Controller } from "@hotwired/stimulus"
import Swiper from 'swiper'
import { Navigation } from 'swiper/modules'

import 'swiper/css'
import 'swiper/css/navigation'

// Connects to data-controller="carousel"
export default class extends Controller {
  static values = {
    spaceBetween: { type: Number, default: 30 }
  }

  connect() {
    this.swiper = new Swiper(this.element, {
      modules: [Navigation],
      loop: true,
      speed: 1400,
      spaceBetween: this.spaceBetweenValue,
      
      // Responsive breakpoints
      breakpoints: {
        320: {
          slidesPerView: 1,
        },
        640: {
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
    })
  }

  disconnect() {
    if (this.swiper) {
      this.swiper.destroy()
    }
  }
}
