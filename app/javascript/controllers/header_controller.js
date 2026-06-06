import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "button"]

  toggle() {
    this.navTarget.classList.toggle("is-open")
    this.buttonTarget.classList.toggle("is-open")
  }

  close() {
    this.navTarget.classList.remove("is-open")
    this.buttonTarget.classList.remove("is-open")
  }
}
