import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "typeSelect", "subtypeSelect", "subtypeContainer" ]

  connect() {
    this.updateSubtypes()
  }

  async updateSubtypes() {
    const selectedType = this.typeSelectTarget.value

    if (!selectedType) {
      this.hideSubtypes()
      return
    }

    try {
      const response = await fetch(`/accounts/subtypes?type=${selectedType}`)
      const subtypes = await response.json()

      if (subtypes.length > 0) {
        this.updateSubtypeDropdown(subtypes)
        this.showSubtypes()
      } else {
        this.hideSubtypes()
      }
    } catch (error) {
      console.error("Failed to fetch subtypes:", error)
      this.hideSubtypes()
    }
  }

  updateSubtypeDropdown(subtypes) {
    const select = this.subtypeSelectTarget
    const currentValue = select.value

    // Clear existing options
    select.innerHTML = '<option value="">None</option>'

    // Add new options
    subtypes.forEach(([ label, value ]) => {
      const option = document.createElement("option")
      option.value = value
      option.textContent = label
      select.appendChild(option)
    })

    // Restore previous selection if still valid
    if (currentValue && subtypes.some(([ _, value ]) => value === currentValue)) {
      select.value = currentValue
    }
  }

  showSubtypes() {
    this.subtypeContainerTarget.classList.remove("hidden")
  }

  hideSubtypes() {
    this.subtypeContainerTarget.classList.add("hidden")
    this.subtypeSelectTarget.value = ""
  }
}
