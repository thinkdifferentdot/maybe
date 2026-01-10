import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["section"];
  static values = { provider: String };

  connect() {
    this.updateVisibility();
  }

  providerChanged(event) {
    this.providerValue = event.target.value;
    this.updateVisibility();
  }

  updateVisibility() {
    this.sectionTargets.forEach(section => {
      const sectionProvider = section.dataset.provider;
      if (sectionProvider === this.providerValue) {
        section.classList.remove("hidden");
      } else {
        section.classList.add("hidden");
      }
    });
  }
}
