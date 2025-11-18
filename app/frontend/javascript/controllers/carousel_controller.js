import { Controller } from "@hotwired/stimulus"
import Swiper from 'swiper'
import { Navigation } from 'swiper/modules'

import 'swiper/css'
import 'swiper/css/navigation'

// Connects to data-controller="carousel"
export default class extends Controller {

  connect() {
    this.swiper = new Swiper(this.element, {
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
    })
  }

  disconnect() {
    if (this.swiper) {
      this.swiper.destroy()
    }
  }
}
