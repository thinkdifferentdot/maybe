class AccountsController < ApplicationController
  before_action :set_account, only: %i[sync sparkline toggle_active show edit update destroy]
  include Periodable

  def index
    @manual_accounts = family.accounts.manual.alphabetically
    @plaid_items = family.plaid_items.ordered

    render layout: "settings"
  end

  def sync_all
    family.sync_later
    redirect_to accounts_path, notice: "Syncing accounts..."
  end

  def show
    @chart_view = params[:chart_view] || "balance"
    @tab = params[:tab]
    @q = params.fetch(:q, {}).permit(:search)
    entries = @account.entries.search(@q).reverse_chronological

    @pagy, @entries = pagy(entries, limit: params[:per_page] || "10")

    @activity_feed_data = Account::ActivityFeedData.new(@account, @entries)
  end

  def sync
    unless @account.syncing?
      @account.sync_later
    end

    redirect_to account_path(@account)
  end

  def sparkline
    etag_key = @account.family.build_cache_key("#{@account.id}_sparkline", invalidate_on_data_updates: true)

    # Short-circuit with 304 Not Modified when the client already has the latest version.
    # We defer the expensive series computation until we know the content is stale.
    if stale?(etag: etag_key, last_modified: @account.family.latest_sync_completed_at)
      @sparkline_series = @account.sparkline_series
      render layout: false
    end
  end

  def toggle_active
    if @account.active?
      @account.disable!
    elsif @account.disabled?
      @account.enable!
    end
    redirect_to accounts_path
  end

  def edit
  end

  def update
    # Check if accountable_type is being changed
    if params[:account][:accountable_type].present? &&
       params[:account][:accountable_type] != @account.accountable_type

      new_type = params[:account][:accountable_type]
      new_subtype = params[:account][:subtype]

      if @account.change_accountable_type!(new_type, new_subtype)
        # Update other account attributes
        @account.update(account_params.except(:accountable_type, :subtype))
        redirect_to @account, notice: "Account type updated successfully"
      else
        @error_message = @account.errors.full_messages.join(", ")
        render :edit, status: :unprocessable_entity
      end
    else
      # Normal update flow (no type change)
      if @account.update(account_params)
        redirect_to @account, notice: "Account updated successfully"
      else
        @error_message = @account.errors.full_messages.join(", ")
        render :edit, status: :unprocessable_entity
      end
    end
  end

  def subtypes
    type = params[:type]
    return render json: [] unless type.present? && Accountable::TYPES.include?(type)

    klass = type.constantize
    return render json: [] unless klass.const_defined?(:SUBTYPES)

    subtypes = klass::SUBTYPES.map { |key, labels| [ labels[:long], key ] }
    render json: subtypes
  end

  def destroy
    if @account.linked?
      redirect_to account_path(@account), alert: "Cannot delete a linked account"
    else
      @account.destroy_later
      redirect_to accounts_path, notice: "Account scheduled for deletion"
    end
  end

  private
    def family
      Current.family
    end

    def set_account
      @account = family.accounts.find(params[:id])
    end

    def account_params
      params.require(:account).permit(:name, :balance, :currency, :accountable_type, :subtype)
    end
end
