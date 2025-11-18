import { Controller } from "@hotwired/stimulus"
import Swiper from 'swiper'
import { Navigation } from 'swiper/modules'

// Import Swiper styles
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
        // when window width is >= 320px (mobile)
        320: {
          slidesPerView: 1,
        },
        // when window width is >= 768px (tablet)
        768: {
          slidesPerView: 3,
        },
        // when window width is >= 1024px (desktop)
        1024: {
          slidesPerView: 4,
        }
      },
      
      // Navigation arrows
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
