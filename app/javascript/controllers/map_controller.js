import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    markers: Array,
    center: { type: Array, default: [139.767125, 35.681236] },
    zoom: { type: Number, default: 5 }
  }

  async connect() {
    const maplibregl = (await import("maplibre-gl")).default

    this.map = new maplibregl.Map({
      container: this.element,
      style: "https://tiles.openfreemap.org/styles/liberty",
      center: this.initialCenter(),
      zoom: this.initialZoom()
    })

    this.map.addControl(new maplibregl.NavigationControl())
    this.map.on("load", () => this.addMarkers())
  }

  disconnect() {
    this.map?.remove()
  }

  initialCenter() {
    if (this.markersValue.length === 0) return this.centerValue

    const lng = this.markersValue.reduce((sum, marker) => sum + marker.lng, 0) / this.markersValue.length
    const lat = this.markersValue.reduce((sum, marker) => sum + marker.lat, 0) / this.markersValue.length
    return [lng, lat]
  }

  initialZoom() {
    return this.markersValue.length > 0 ? 10 : this.zoomValue
  }

  addMarkers() {
    this.markersValue.forEach((marker) => {
      const popup = new maplibregl.Popup({ offset: 25 }).setHTML(
        `<strong>${this.escapeHtml(marker.name)}</strong><br>` +
        `${this.escapeHtml(marker.address)}<br>` +
        `<a href="${this.escapeHtml(marker.url)}">詳細</a>`
      )

      new maplibregl.Marker()
        .setLngLat([marker.lng, marker.lat])
        .setPopup(popup)
        .addTo(this.map)
    })
  }

  escapeHtml(text) {
    return String(text)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
  }
}
