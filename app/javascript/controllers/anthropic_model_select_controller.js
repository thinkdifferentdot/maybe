import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="anthropic-model-select"
export default class extends Controller {
  static targets = ["select", "customInputWrapper", "customInput", "spinner", "error"];
  static values = {
    currentModel: String,
    customOptionValue: { type: String, default: "custom" }
  };

  connect() {
    this.fetchModels();
  }

  async fetchModels() {
    try {
      this.showLoading();

      const csrfToken = document.querySelector('[name="csrf-token"]');
      const headers = {
        Accept: "application/json",
      };
      if (csrfToken) {
        headers["X-CSRF-Token"] = csrfToken.content;
      }

      const response = await fetch("/settings/hosting/anthropic_models", { headers });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();

      if (data.error) {
        this.showError(data.error);
        return;
      }

      this.populateSelect(data.models);
    } catch (error) {
      console.error("Error fetching Anthropic models:", error);
      this.showError(this.defaultErrorMessage);
    } finally {
      this.hideLoading();
    }
  }

  populateSelect(models) {
    if (!this.hasSelectTarget) return;

    const select = this.selectTarget;
    const currentValue = this.currentModelValue || select.value;

    // Clear existing options
    select.innerHTML = "";

    // Add empty option as placeholder
    const emptyOption = document.createElement("option");
    emptyOption.value = "";
    emptyOption.textContent = this.selectTarget.dataset.placeholder || "";
    emptyOption.disabled = true;
    emptyOption.selected = !currentValue;
    select.appendChild(emptyOption);

    // Add fetched models
    models.forEach((model) => {
      const option = document.createElement("option");
      option.value = model.id;
      option.textContent = model.display_name || model.id;
      if (model.id === currentValue) {
        option.selected = true;
      }
      select.appendChild(option);
    });

    // Add "Custom..." option
    const customOption = document.createElement("option");
    customOption.value = this.customOptionValue;
    customOption.textContent = this.customOptionLabel;
    if (currentValue && !models.find((m) => m.id === currentValue)) {
      // If current value is not in the list, it's a custom model
      customOption.selected = true;
    }
    select.appendChild(customOption);

    // Show custom input if custom option is selected
    this.updateCustomInputVisibility();
  }

  change(event) {
    this.updateCustomInputVisibility();

    // If a non-custom option is selected, update the hidden input with the select value
    if (event.target.value !== this.customOptionValue && this.hasCustomInputTarget) {
      this.customInputTarget.value = event.target.value;
      // Trigger auto-submit on the parent form
      const form = this.element.closest("form");
      if (form) {
        form.requestSubmit();
      }
    }
  }

  customInputChange(event) {
    // When custom input changes, sync to select value if needed
    // and trigger form submission
    const form = this.element.closest("form");
    if (form) {
      form.requestSubmit();
    }
  }

  updateCustomInputVisibility() {
    if (!this.hasSelectTarget || !this.hasCustomInputWrapperTarget) return;

    const isCustom = this.selectTarget.value === this.customOptionValue;

    if (isCustom) {
      this.customInputWrapperTarget.classList.remove("hidden");
      if (this.hasCustomInputTarget && this.currentModelValue) {
        this.customInputTarget.value = this.currentModelValue;
      }
      // Focus on custom input when custom option is selected
      if (this.hasCustomInputTarget) {
        this.customInputTarget.focus();
      }
    } else {
      this.customInputWrapperTarget.classList.add("hidden");
    }
  }

  showLoading() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden");
    }
    if (this.hasSelectTarget) {
      this.selectTarget.disabled = true;
    }
  }

  hideLoading() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("hidden");
    }
    if (this.hasSelectTarget) {
      this.selectTarget.disabled = false;
    }
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message;
      this.errorTarget.classList.remove("hidden");
    }
  }

  get customOptionLabel() {
    return this.data.get("customOptionLabel") || "Custom...";
  }

  get defaultErrorMessage() {
    return this.data.get("defaultErrorMessage") || "Failed to load models";
  }
}
