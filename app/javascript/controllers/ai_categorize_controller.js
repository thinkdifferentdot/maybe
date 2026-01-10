import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "icon"];
  static values = {
    transactionId: String,
  };

  categorize(event) {
    event.preventDefault();

    const csrfToken = document.querySelector('meta[name="csrf-token"]');
    if (!csrfToken) {
      console.error("[AI Categorize] CSRF token not found.");
      return;
    }

    // Set loading state
    this._setLoadingState(true);

    fetch("/transactions/ai_categorization", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken.content,
        "Accept": "text/vnd.turbo-stream.html",
      },
      body: new URLSearchParams({
        transaction_id: this.transactionIdValue,
      }),
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

        // Keep button disabled briefly for visual feedback, then re-enable
        setTimeout(() => {
          this._setLoadingState(false);
        }, 500);
      })
      .catch((error) => {
        console.error("[AI Categorize] Error:", error);
        this._setLoadingState(false);
        this._showError();
      });
  }

  _setLoadingState(isLoading) {
    if (isLoading) {
      this.element.disabled = true;
      this.element.setAttribute("aria-disabled", "true");
      this.element.setAttribute("aria-busy", "true");
      this.element.innerHTML = `
        <span class="animate-spin rounded-full h-4 w-4 border-b-2 border-current" aria-hidden="true"></span>
      `;
    } else {
      this.element.disabled = false;
      this.element.removeAttribute("aria-disabled");
      this.element.removeAttribute("aria-busy");
      this.element.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4"><path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"></path></svg>`;
    }
  }

  _showError() {
    // Trigger a flash notification via turbo stream
    const event = new CustomEvent("flash:show", {
      detail: { type: "error", message: this._errorMessage() },
    });
    document.dispatchEvent(event);
  }

  _errorMessage() {
    const key = "transactions.ai_categorize.error";
    return window.I18n?.t?.(key) || "Failed to categorize. Please try again.";
  }
}
