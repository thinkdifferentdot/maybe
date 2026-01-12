import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "container"];
  static values = {
    transactionId: String,
    feedbackType: String,
  };

  send(event) {
    event.preventDefault();

    const csrfToken = document.querySelector('meta[name="csrf-token"]');
    if (!csrfToken) {
      console.error("[AI Feedback] CSRF token not found.");
      return;
    }

    const button = event.currentTarget;
    const feedbackType = button.dataset.feedbackType || this.feedbackTypeValue;
    const url = feedbackType === "reject"
      ? "/transactions/ai_feedback/reject"
      : "/transactions/ai_feedback/approve";

    // Set loading state
    this._setLoadingState(true);

    fetch(url, {
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
        this._setLoadingState(false);
      })
      .catch((error) => {
        console.error("[AI Feedback] Error:", error);
        this._setLoadingState(false);
        this._showError();
      });
  }

  _setLoadingState(isLoading) {
    if (this.hasContainerTarget) {
      // Disable all buttons in the container
      this.buttonTargets.forEach((button) => {
        button.disabled = isLoading;
        button.setAttribute("aria-disabled", isLoading.toString());
        button.setAttribute("aria-busy", isLoading.toString());
      });
    } else if (this.hasButtonTarget) {
      this.buttonTargets.forEach((button) => {
        button.disabled = isLoading;
        button.setAttribute("aria-disabled", isLoading.toString());
        button.setAttribute("aria-busy", isLoading.toString());
      });
    }
  }

  _showError() {
    // Trigger a flash notification via custom event
    const event = new CustomEvent("flash:show", {
      detail: { type: "error", message: this._errorMessage() },
    });
    document.dispatchEvent(event);
  }

  _errorMessage() {
    const key = "transactions.feedback.error";
    return window.I18n?.t?.(key) || "Failed to submit feedback. Please try again.";
  }
}
