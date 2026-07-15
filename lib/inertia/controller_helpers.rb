# frozen_string_literal: true

require "uri"

module Inertia
  ##
  # Provides controller helper methods for Inertia.js integration.
  module ControllerHelpers
    # Redirects the client to the specified location.
    #
    # @param location [String] the URL to redirect to
    # @param external [Boolean] whether to force an external (full page) redirect.
    #   When `true`, the browser will perform a full page visit instead of an Inertia visit
    #
    # @example Basic redirect
    #   redirect_to "/dashboard"
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
      headers["location"] = location
    end

    # Redirects the client back to the referring page, with a fallback location.
    #
    # @param fallback_location [String] the URL to redirect to if there is no referer
    # @param external [Boolean] whether to force an external (full page) redirect.
    #   When `true`, the browser will perform a full page visit instead of an Inertia visit
    #
    # @example Redirect back with a fallback
    #   redirect_back fallback_location: "/dashboard"
    #
    # @see #redirect_back_or_to
    def redirect_back(fallback_location:, external: false)
      redirect_back_or_to fallback_location, external:
    end

    # Redirects the client back to the referring page, or to the specified fallback location.
    #
    # @param fallback_location [String] the URL to redirect to if there is no referer
    # @param external [Boolean] whether to force an external (full page) redirect.
    #   When `true`, the browser will perform a full page visit instead of an Inertia visit
    #
    # @example Redirect back or to a fallback
    #   redirect_back_or_to "/dashboard"
    #
    # @example Force an external redirect
    #   redirect_back_or_to "/dashboard", external: true
    def redirect_back_or_to(fallback_location, external: false)
      referer = request.env["HTTP_REFERER"]

      if referer
        redirect_to referer, external:
      else
        redirect_to fallback_location, external:
      end
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
