class LunchflowConnectionsController < ApplicationController
  before_action :set_connection, only: [ :show, :edit, :update, :destroy, :sync ]

  def index
    @connections = Current.family.lunchflow_connections.ordered
  end

  def show
  end

  def new
    @connection = LunchflowConnection.new
  end

  def create
    @connection = Current.family.lunchflow_connections.build(connection_params)

    if @connection.save
      redirect_to lunchflow_connections_path, notice: "Connection created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @connection.update(connection_params)
      redirect_to lunchflow_connections_path, notice: "Connection updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @connection.destroy
    redirect_to lunchflow_connections_path, notice: "Connection deleted."
  end

  def sync
    @connection.sync_later
    redirect_to lunchflow_connections_path, notice: "Sync started for #{@connection.name}"
  end

  private

    def set_connection
      @connection = Current.family.lunchflow_connections.find(params[:id])
    end

    def connection_params
      params.require(:lunchflow_connection).permit(:name)
    end
end
