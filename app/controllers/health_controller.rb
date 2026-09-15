class HealthController < ApplicationController
  def show
    if database_connected?
      render json: { status: "ok", database: "connected" }
    else
      render json: { status: "error", database: "disconnected" },
             status: :service_unavailable
    end
  end

  private

  def database_connected?
    ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") }
    true
  rescue ActiveRecord::ActiveRecordError, PG::Error => e
    Rails.logger.error("Health check could not reach the database: #{e.class}: #{e.message}")
    false
  end
end
