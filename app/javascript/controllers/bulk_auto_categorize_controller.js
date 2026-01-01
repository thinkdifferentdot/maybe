import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "loadingState",
    "previewContent",
    "errorState",
    "previewTemplate",
    "checkbox",
    "selectedCount",
    "form"
  ]

  connect() {
    this.predictions = []
  }

  async openPreview(event) {
    event.preventDefault()

    // Get selected entry IDs from bulk-select controller
    const bulkSelectElement = document.querySelector('[data-controller*="bulk-select"]')
    const bulkSelectController = this.application.getControllerForElementAndIdentifier(
      bulkSelectElement,
      "bulk-select"
    )

    const selectedEntryIds = bulkSelectController.selectedIdsValue

    if (selectedEntryIds.length === 0) {
      alert("Please select at least one transaction")
      return
    }

    // Open modal and show loading state
    this.showLoading()
    this.openModal()

    // Fetch predictions
    try {
      const response = await fetch('/transactions/bulk_auto_categorization/preview', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ entry_ids: selectedEntryIds })
      })

      const data = await response.json()

      if (response.ok) {
        this.predictions = data.predictions
        this.renderPreview(data.predictions)
      } else {
        this.showError(data.error || "Failed to categorize transactions")
      }
    } catch (error) {
      console.error("Auto-categorization error:", error)
      this.showError("Network error. Please try again.")
    }
  }

  renderPreview(predictions) {
    const container = this.previewContentTarget.querySelector('[data-bulk-auto-categorize-target="previewTemplate"]').parentElement

    // Clear existing previews (except template)
    container.querySelectorAll(':not(template)').forEach(el => el.remove())

    predictions.forEach((prediction) => {
      const template = this.previewTemplateTarget.content.cloneNode(true)
      const div = template.querySelector('div')

      // Set data
      div.querySelector('[data-field="name"]').textContent = prediction.transaction_name
      div.querySelector('[data-field="account"]').textContent = prediction.account_name
      div.querySelector('[data-field="category"]').textContent = prediction.category_name || "Uncategorized"
      div.querySelector('[data-field="amount"]').textContent = prediction.amount

      // Set checkbox value
      const checkbox = div.querySelector('input[type="checkbox"]')
      checkbox.value = JSON.stringify({
        entry_id: prediction.entry_id,
        category_id: prediction.category_id
      })
      checkbox.checked = prediction.category_id !== null
      checkbox.disabled = prediction.category_id === null

      // Add gray styling for uncategorized
      if (prediction.category_id === null) {
        div.classList.add('opacity-50')
      }

      container.appendChild(template)
    })

    this.updateSelectedCount()
    this.showPreview()
  }

  updateSelectedCount() {
    const checkedCount = this.checkboxTargets.filter(cb => cb.checked && !cb.disabled).length
    const totalCount = this.checkboxTargets.filter(cb => !cb.disabled).length
    this.selectedCountTarget.textContent = `${checkedCount} of ${totalCount}`
  }

  showLoading() {
    this.loadingStateTarget.classList.remove('hidden')
    this.previewContentTarget.classList.add('hidden')
    this.errorStateTarget.classList.add('hidden')
  }

  showPreview() {
    this.loadingStateTarget.classList.add('hidden')
    this.previewContentTarget.classList.remove('hidden')
    this.errorStateTarget.classList.add('hidden')
  }

  showError(message) {
    this.errorStateTarget.querySelector('[data-field="errorMessage"]').textContent = message
    this.loadingStateTarget.classList.add('hidden')
    this.previewContentTarget.classList.add('hidden')
    this.errorStateTarget.classList.remove('hidden')
  }

  openModal() {
    const dialog = this.element.closest('dialog')
    if (dialog && typeof dialog.showModal === 'function') {
      dialog.showModal()
    }
  }

  closeModal(event) {
    if (event) event.preventDefault()

    const dialog = this.element.closest('dialog')
    if (dialog && typeof dialog.close === 'function') {
      dialog.close()
    }
  }

  applyCategories(event) {
    event.preventDefault()

    // Form will submit with checked predictions via Turbo
    this.formTarget.requestSubmit()
  }
}
