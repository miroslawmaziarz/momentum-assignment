class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_failed
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_unparseable_body

  private

  def render_validation_failed(exception)
    render_error(
      code: "validation_failed",
      message: exception.message,
      status: :unprocessable_content,
      details: exception.record.errors.messages
    )
  end

  def render_not_found(exception)
    render_error(code: "not_found", message: exception.message, status: :not_found)
  end

  def render_parameter_missing(exception)
    render_error(
      code: "bad_request",
      message: "Missing required parameter: #{exception.param}.",
      status: :bad_request
    )
  end

  def render_unparseable_body(_exception)
    render_error(
      code: "bad_request",
      message: "Request body could not be parsed as JSON.",
      status: :bad_request
    )
  end

  def render_error(code:, message:, status:, details: nil)
    body = { code:, message: }
    body[:details] = details if details.present?

    render json: { error: body }, status:
  end
end
