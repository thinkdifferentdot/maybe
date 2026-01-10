import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="bulk-select"
export default class extends Controller {
  static targets = [
    "row",
    "group",
    "selectionBar",
    "selectionBarText",
    "bulkEditDrawerHeader",
    "costDisplay",
  ];
  static values = {
    singularLabel: String,
    pluralLabel: String,
    selectedIds: { type: Array, default: [] },
    categoryCount: { type: Number, default: 0 },
    modelName: { type: String, default: "gpt-4.1" },
  };

  connect() {
    document.addEventListener("turbo:load", this._updateView);

    this._updateView();
  }

  disconnect() {
    document.removeEventListener("turbo:load", this._updateView);
  }

  bulkEditDrawerHeaderTargetConnected(element) {
    const headingTextEl = element.querySelector("h2");
    headingTextEl.innerText = `Edit ${
      this.selectedIdsValue.length
    } ${this._pluralizedResourceName()}`;
  }

  submitBulkRequest(e) {
    const form = e.target.closest("form");
    const scope = e.params.scope;
    this._addHiddenFormInputsForSelectedIds(
      form,
      `${scope}[entry_ids][]`,
      this.selectedIdsValue,
    );
    form.requestSubmit();
  }

  togglePageSelection(e) {
    if (e.target.checked) {
      this._selectAll();
    } else {
      this.deselectAll();
    }
  }

  toggleGroupSelection(e) {
    const group = this.groupTargets.find((group) => group.contains(e.target));

    this._rowsForGroup(group).forEach((row) => {
      if (e.target.checked) {
        this._addToSelection(row.dataset.id);
      } else {
        this._removeFromSelection(row.dataset.id);
      }
    });
  }

  toggleRowSelection(e) {
    if (e.target.checked) {
      this._addToSelection(e.target.dataset.id);
    } else {
      this._removeFromSelection(e.target.dataset.id);
    }
  }

  deselectAll() {
    this.selectedIdsValue = [];
    this.element.querySelectorAll('input[type="checkbox"]').forEach((el) => {
      el.checked = false;
    });
  }

  selectedIdsValueChanged() {
    this._updateView();
  }

  _addHiddenFormInputsForSelectedIds(form, paramName, transactionIds) {
    this._resetFormInputs(form, paramName);

    transactionIds.forEach((id) => {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = paramName;
      input.value = id;
      form.appendChild(input);
    });
  }

  _resetFormInputs(form, paramName) {
    const existingInputs = form.querySelectorAll(`input[name='${paramName}']`);
    existingInputs.forEach((input) => input.remove());
  }

  _rowsForGroup(group) {
    return this.rowTargets.filter(
      (row) => group.contains(row) && !row.disabled,
    );
  }

  _addToSelection(idToAdd) {
    this.selectedIdsValue = Array.from(
      new Set([...this.selectedIdsValue, idToAdd]),
    );
  }

  _removeFromSelection(idToRemove) {
    this.selectedIdsValue = this.selectedIdsValue.filter(
      (id) => id !== idToRemove,
    );
  }

  _selectAll() {
    this.selectedIdsValue = this.rowTargets
      .filter((t) => !t.disabled)
      .map((t) => t.dataset.id);
  }

  _updateView = () => {
    this._updateSelectionBar();
    this._updateGroups();
    this._updateRows();
  };

  _updateSelectionBar() {
    const count = this.selectedIdsValue.length;
    this.selectionBarTextTarget.innerText = `${count} ${this._pluralizedResourceName()} selected`;
    this.selectionBarTarget.classList.toggle("hidden", count === 0);
    this.selectionBarTarget.querySelector("input[type='checkbox']").checked =
      count > 0;
    this._updateCostEstimation();
  }

  _updateCostEstimation() {
    if (!this.hasCostDisplayTarget) return;

    const count = this.selectedIdsValue.length;
    if (count === 0) {
      this.costDisplayTarget.innerText = "";
      return;
    }

    const cost = this._estimateCost(count);
    const key = "transactions.bulk_ai_categorize.cost_estimate";
    const message = window.I18n?.t?.(key, { cost: cost.toFixed(4) }) || `Est: $${cost.toFixed(4)}`;
    this.costDisplayTarget.innerText = message;
  }

  _estimateCost(selectedCount) {
    // Simple client-side estimation based on LlmUsage.estimate_auto_categorize_cost
    // Formula: (selected_count * 100 tokens + category_count * 50 + 150 base) * model_pricing
    const basePromptTokens = 150;
    const transactionTokens = selectedCount * 100;
    const categoryTokens = this.categoryCountValue * 50;
    const estimatedPromptTokens = basePromptTokens + transactionTokens + categoryTokens;
    const estimatedCompletionTokens = selectedCount * 50;

    // Rough pricing per 1M tokens (will be refined with actual backend data)
    const modelPricing = this._getModelPricing();
    const promptCost = (estimatedPromptTokens * modelPricing.prompt) / 1_000_000;
    const completionCost = (estimatedCompletionTokens * modelPricing.completion) / 1_000_000;

    return promptCost + completionCost;
  }

  _getModelPricing() {
    // Default pricing (GPT-4.1 per 1M tokens)
    const pricing = {
      "gpt-4.1": { prompt: 2.00, completion: 8.00 },
      "gpt-4o": { prompt: 2.50, completion: 10.00 },
      "gpt-4o-mini": { prompt: 0.15, completion: 0.60 },
      "claude-sonnet-4": { prompt: 3.00, completion: 15.00 },
      "claude-sonnet-3.5": { prompt: 3.00, completion: 15.00 },
      "claude-haiku-3.5": { prompt: 0.80, completion: 4.00 },
    };

    // Check for prefix match (e.g., "gpt-4.1-2024-08-06" matches "gpt-4.1")
    for (const [model, cost] of Object.entries(pricing)) {
      if (this.modelNameValue.startsWith(model)) {
        return cost;
      }
    }

    return pricing["gpt-4.1"];
  }

  _pluralizedResourceName() {
    if (this.selectedIdsValue.length === 1) {
      return this.singularLabelValue;
    }

    return this.pluralLabelValue;
  }

  _updateGroups() {
    this.groupTargets.forEach((group) => {
      const rows = this.rowTargets.filter(
        (row) => group.contains(row) && !row.disabled,
      );
      const groupSelected =
        rows.length > 0 &&
        rows.every((row) => this.selectedIdsValue.includes(row.dataset.id));
      group.querySelector("input[type='checkbox']").checked = groupSelected;
    });
  }

  _updateRows() {
    this.rowTargets.forEach((row) => {
      row.checked = this.selectedIdsValue.includes(row.dataset.id);
    });
  }
}
