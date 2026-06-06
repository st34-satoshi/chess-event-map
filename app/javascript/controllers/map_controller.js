import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    markers: Array,
    center: { type: Array, default: [139.767125, 35.681236] },
    zoom: { type: Number, default: 5 }
  }

  async connect() {
    this.maplibregl = (await import("maplibre-gl")).default

    this.map = new this.maplibregl.Map({
      container: this.element,
      style: "https://tiles.openfreemap.org/styles/liberty",
      center: this.initialCenter(),
      zoom: this.initialZoom()
    })

    this.map.addControl(new this.maplibregl.NavigationControl())
    this.map.on("load", () => this.addClusterLayers())
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

  geojson() {
    return {
      type: "FeatureCollection",
      features: this.markersValue.map((marker) => ({
        type: "Feature",
        properties: {
          name: marker.name,
          address: marker.address,
          url: marker.url
        },
        geometry: {
          type: "Point",
          coordinates: [marker.lng, marker.lat]
        }
      }))
    }
  }

  addClusterLayers() {
    const { map, maplibregl } = this

    map.addSource("places", {
      type: "geojson",
      data: this.geojson(),
      cluster: true,
      clusterMaxZoom: 14,
      clusterRadius: 50,
      clusterProperties: {
        place_name: ["concat", ["get", "name"]]
      }
    })

    map.addLayer({
      id: "clusters",
      type: "circle",
      source: "places",
      filter: ["has", "point_count"],
      paint: {
        "circle-color": [
          "step",
          ["get", "point_count"],
          "#51bbd6",
          5,
          "#f1f075",
          10,
          "#f28cb1"
        ],
        "circle-radius": [
          "step",
          ["get", "point_count"],
          18,
          5,
          24,
          10,
          30
        ],
        "circle-stroke-width": 2,
        "circle-stroke-color": "#333"
      }
    })

    map.addLayer({
      id: "cluster-count",
      type: "symbol",
      source: "places",
      filter: ["all", ["has", "point_count"], [">", ["get", "point_count"], 1]],
      layout: {
        "text-field": "{point_count_abbreviated}",
        "text-size": 12
      }
    })

    map.addLayer({
      id: "unclustered-point",
      type: "circle",
      source: "places",
      filter: ["!", ["has", "point_count"]],
      paint: {
        "circle-color": "#11b4da",
        "circle-radius": 8,
        "circle-stroke-width": 2,
        "circle-stroke-color": "#fff"
      }
    })

    map.addLayer({
      id: "single-place-label",
      type: "symbol",
      source: "places",
      filter: [
        "any",
        ["!", ["has", "point_count"]],
        ["all", ["has", "point_count"], ["==", ["get", "point_count"], 1]]
      ],
      layout: {
        "text-field": ["coalesce", ["get", "name"], ["get", "place_name"]],
        "text-size": 11,
        "text-offset": [0, 1.2],
        "text-anchor": "top",
        "text-max-width": 10
      },
      paint: {
        "text-color": "#1a1a1a",
        "text-halo-color": "#ffffff",
        "text-halo-width": 1.5
      }
    })

    map.on("click", "clusters", async (event) => {
      const features = map.queryRenderedFeatures(event.point, { layers: ["clusters"] })
      if (features.length === 0) return

      const clusterId = features[0].properties.cluster_id
      const zoom = await map.getSource("places").getClusterExpansionZoom(clusterId)

      map.easeTo({
        center: features[0].geometry.coordinates,
        zoom
      })
    })

    const showPlacePopup = (event) => {
      const feature = event.features[0]
      const coordinates = feature.geometry.coordinates.slice()
      const { address, url } = feature.properties
      const name = feature.properties.name || feature.properties.place_name

      while (Math.abs(event.lngLat.lng - coordinates[0]) > 180) {
        coordinates[0] += event.lngLat.lng > coordinates[0] ? 360 : -360
      }

      new maplibregl.Popup()
        .setLngLat(coordinates)
        .setHTML(
          `<strong>${this.escapeHtml(name)}</strong><br>` +
          `${this.escapeHtml(address)}<br>` +
          `<a href="${this.escapeHtml(url)}">詳細</a>`
        )
        .addTo(map)
    }

    map.on("click", "unclustered-point", showPlacePopup)
    map.on("click", "single-place-label", showPlacePopup)

    this.setCursorPointer("clusters")
    this.setCursorPointer("unclustered-point")
    this.setCursorPointer("single-place-label")
  }

  setCursorPointer(layerId) {
    this.map.on("mouseenter", layerId, () => {
      this.map.getCanvas().style.cursor = "pointer"
    })
    this.map.on("mouseleave", layerId, () => {
      this.map.getCanvas().style.cursor = ""
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
