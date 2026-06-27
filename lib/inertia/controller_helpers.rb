# frozen_string_literal: true

module Inertia
  ##
  # Provides controller helper methods for Inertia.js integration.
  module ControllerHelpers
    # Redirects the client to the specified location.
    #
    # @param location [String, Symbol] the URL to redirect to, or `:back` to redirect to the referring page
    # @param external [Boolean] whether to force an external (full page) redirect.
    #   When `true`, the browser will perform a full page visit instead of an Inertia visit
    #
    # @example Basic redirect
    #   redirect_to "/dashboard"
    #
    # @example Redirect back to the previous page
    #   redirect_to :back
    #
    # @example Force an external redirect
    #   redirect_to "https://example.com", external: true
    def redirect_to(location, external: false)
      if external
        headers["x-inertia-location"] = location
        head 409
        return
      end

      head(request.get? || request.post? ? 302 : 303)
      headers["location"] = location == :back ? request.env["HTTP_REFERER"] : location
    end

    private

    # Appends additional request information to the log payload.
    #
    # This method is called by the framework to enrich log entries with
    # request parameters. Parameters are only included in development mode
    # to avoid logging sensitive data in production.
    def append_info_to_payload(context)
      context[:params] = params if Rage.env.development?
    end
  end
end
