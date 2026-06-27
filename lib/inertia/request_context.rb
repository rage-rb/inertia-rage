# frozen_string_literal: true

module Inertia
  ##
  # Encapsulates request-specific context for Inertia partial reloads.
  class RequestContext
    # Creates a new request context.
    #
    # @param request [Rage::Request] the HTTP request object
    # @param component [String] the Inertia component name being rendered
    def initialize(request, component:)
      @request = request
      @component = component
    end

    # Returns the full request path including query string.
    # @return [String] the request URL path
    def url
      @request.fullpath
    end

    # Determines the inclusion status of a prop based on partial reload headers.
    #
    # @param prop_name [String] the full path of the prop (e.g., "user.profile")
    # @return [Symbol] the prop status:
    #   - `:unspecified` - no partial reload filtering applies
    #   - `:requested` - prop is explicitly requested in partial reload
    #   - `:excluded` - prop is excluded from partial reload
    def prop_status(prop_name)
      return :unspecified unless partial_render?

      is_excluded = partial_except.any? do |except_prop_name|
        prop_name == except_prop_name ||
          (prop_name.start_with?(except_prop_name) && prop_name.start_with?("#{except_prop_name}."))
      end

      return :excluded if is_excluded
      return :requested if partial_only.empty? && partial_except.any?
      return :unspecified if partial_only.empty?

      is_included_in_partial_reload = partial_only.any? do |only_prop_name|
        prop_name == only_prop_name ||
          (only_prop_name.start_with?(prop_name) && only_prop_name.start_with?("#{prop_name}.")) ||
          (prop_name.start_with?(only_prop_name) && prop_name.start_with?("#{only_prop_name}."))
      end

      is_included_in_partial_reload ? :requested : :excluded
    end

    # Checks if a once prop should be excluded based on the client's cached props.
    #
    # @param prop_name [String] the cache key of the once prop
    # @return [Boolean] `true` if the client already has this prop cached
    def once_prop_excluded?(prop_name)
      except_once.include?(prop_name)
    end

    # Checks if this is a partial reload request for the current component.
    # @return [Boolean] `true` if the client requested a partial reload for this component
    def partial_render?
      partial_component == @component
    end

    private

    def partial_except
      @partial_except ||= @request.env["HTTP_X_INERTIA_PARTIAL_EXCEPT"]&.split(",") || []
    end

    def partial_only
      @partial_only ||= @request.env["HTTP_X_INERTIA_PARTIAL_DATA"]&.split(",") || []
    end

    def except_once
      @except_once ||= @request.env["HTTP_X_INERTIA_EXCEPT_ONCE_PROPS"]&.split(",") || []
    end

    def partial_component
      @partial_component ||= @request.env["HTTP_X_INERTIA_PARTIAL_COMPONENT"]
    end
  end
end
