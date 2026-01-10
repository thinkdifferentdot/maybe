import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="bulk-ai-categorize"
// Handles the bulk AI categorization workflow
export default class extends Controller {
  static targets = ["applyButton", "costDisplay"];
  static values = {
    url: String,
  };

  connect() {
    this._bindEvents();
  }

  disconnect() {
    this._unbindEvents();
  }

  categorize(event) {
    event.preventDefault();

    const form = event.target.closest("form");
    const formData = new FormData(form);

    // Set loading state
    this._setLoadingState(true);

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": this._getCsrfToken(),
        "Accept": "text/vnd.turbo-stream.html",
      },
      body: formData,
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.text();
      })
      .then((html) => {
        // Turbo will handle the stream response automatically
        Turbo.renderStreamMessage(html);
      })
      .catch((error) => {
        console.error("[Bulk AI Categorize] Error:", error);
        this._showError();
      })
      .finally(() => {
        this._setLoadingState(false);
      });
  }

  skipAll() {
    // Close the confirmation dialog without applying
    this._closeDialog();
  }

  applySelected() {
    // Get selected transaction IDs from checkboxes
    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]:checked');
    const transactionIds = Array.from(checkboxes).map(cb => cb.dataset.transactionId);

    if (transactionIds.length === 0) {
      this._closeDialog();
      return;
    }

    // Submit to apply only selected transactions
    this._applyCategories(transactionIds);
  }

  _applyCategories(transactionIds) {
    const csrfToken = this._getCsrfToken();

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html",
      },
      body: new URLSearchParams({
        "bulk_ai_categorize[entry_ids][]": transactionIds,
        confirmed: "true",
      }),
    })
      .then((response) => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.text();
      })
      .then((html) => {
        Turbo.renderStreamMessage(html);
        this._closeDialog();
      })
      .catch((error) => {
        console.error("[Bulk AI Categorize] Error applying categories:", error);
        this._showError();
      });
  }

  _setLoadingState(isLoading) {
    const buttons = this.element.querySelectorAll('button[data-action*="bulk-ai-categorize"]');
    buttons.forEach((button) => {
      button.disabled = isLoading;
      if (isLoading) {
        button.setAttribute("aria-busy", "true");
      } else {
        button.removeAttribute("aria-busy");
      }
    });
  }

  _closeDialog() {
    const dialog = this.element.closest("turbo-frame");
    if (dialog) {
      dialog.remove();
    }
  }

  _getCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  _showError() {
    const event = new CustomEvent("flash:show", {
      detail: { type: "error", message: this._errorMessage() },
    });
    document.dispatchEvent(event);
  }

  _errorMessage() {
    const key = "transactions.bulk_ai_categorize.error";
    return window.I18n?.t?.(key) || "Failed to categorize. Please try again.";
  }

  _bindEvents() {
    // Listen for successful categorization to clear selections
    document.addEventListener("turbo:before-stream-render", this._handleStreamRender);
  }

  _unbindEvents() {
    document.removeEventListener("turbo:before-stream-render", this._handleStreamRender);
  }

  _handleStreamRender = (event) => {
    // Check if this is a bulk AI categorization response
    const stream = event.target;
    if (stream && stream.target === "flash") {
      // Clear selections after successful bulk operation
      const bulkSelectController = document.querySelector('[data-controller*="bulk-select"]');
      if (bulkSelectController) {
        const event = new CustomEvent("bulk-select:deselectAll");
        bulkSelectController.dispatchEvent(event);
      }
    }
  };
}
