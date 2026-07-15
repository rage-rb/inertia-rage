# frozen_string_literal: true

require "uri"

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

    def self.included(klass)
      klass.before_action :protect_from_csrf
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

    def protect_from_csrf
      # safe methods are always allowed
      method = request.env["REQUEST_METHOD"]
      return if method == "GET" || method == "HEAD" || method == "OPTIONS"

      sec_fetch_site = request.env["HTTP_SEC_FETCH_SITE"]
      return if sec_fetch_site == "same-origin" || sec_fetch_site == "none"

      # check the Origin header
      if sec_fetch_site.nil?
        origin = request.env["HTTP_ORIGIN"]
        # either the request is same-origin or not a browser request
        return unless origin

        begin
          origin_host = URI(origin).authority
          return if origin_host == request.env["HTTP_HOST"]
        rescue URI::InvalidURIError
          # fallthrough
        end
      end

      render plain: "CSRF rejected", status: 403
    end
  end
end
