import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "placeId", "results", "option", "empty"]
  static values = { selectedId: String, selectedName: String }

  connect() {
    if (this.hasSelectedIdValue && this.selectedIdValue) {
      this.placeIdTarget.value = this.selectedIdValue
      this.queryTarget.value = this.selectedNameValue
    }
  }

  filter() {
    const query = this.queryTarget.value.toLowerCase().trim()
    this.placeIdTarget.value = ""

    let visibleCount = 0
    this.optionTargets.forEach((option) => {
      const match = query === "" || option.dataset.searchText.includes(query)
      option.hidden = !match
      if (match) visibleCount++
    })

    this.resultsTarget.hidden = false
    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = visibleCount > 0
    }
  }

  select(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.placeIdTarget.value = button.dataset.placeId
    this.queryTarget.value = button.dataset.placeName
    this.resultsTarget.hidden = true
  }

  showResults() {
    this.filter()
  }

  hideResults() {
    setTimeout(() => {
      this.resultsTarget.hidden = true
    }, 150)
  }
}
