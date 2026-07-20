# frozen_string_literal: true

module Inertia
  ##
  # Stores global configuration options for the Inertia integration.
  #
  # @example Configure via block
  #   Inertia.configure do |config|
  #     config.frontend_path = "client"
  #     config.build_path = "public/dist"
  #     config.build_on_start = false
  #
  #     config.dev_server.host = "0.0.0.0"
  #     config.dev_server.port = 3000
  #   end
  #
  class Configuration
    # @private
    def initialize
      @build_on_start = !Rage.env.development?
    end

    # Set whether to build frontend assets on server start.
    #
    # @param value [Boolean]
    # @see #build_on_start?
    def build_on_start=(value)
      @build_on_start = value
    end

    # Returns whether frontend assets should be built when the server starts.
    #
    # Defaults to `true` in non-development environments.
    #
    # @return [Boolean]
    def build_on_start?
      !!@build_on_start
    end

    # Returns the configured frontend directory path.
    #
    # @return [Pathname, nil]
    # @see #frontend_path=
    def frontend_path
      @frontend_path
    end

    # Sets the path to the frontend application directory.
    #
    # When set, this overrides automatic Vite config detection. The path should
    # be relative to the application root.
    #
    # @param path [String] path relative to the application root
    def frontend_path=(path)
      @frontend_path = Rage.root.join(path)
    end

    # Returns the configured build output path.
    #
    # @return [Pathname, nil]
    # @see #build_path=
    def build_path
      @build_path
    end

    # Sets the path where built frontend assets are located.
    #
    # When set, this overrides the default `dist` directory inside {#frontend_path}.
    # The path should be relative to the application root.
    #
    # Building directly into `public/` is not supported because a root-level
    # `index.html` would intercept all requests to the application's `/` endpoint.
    # Use a nested directory instead, e.g., `public/dist`.
    #
    # @param path [String] path relative to the application root
    # @raise [ArgumentError] if path resolves to the public directory root
    # @note This setting should be paired with updating the `build.outDir` option in your Vite config.
    def build_path=(path)
      @build_path = Rage.root.join(path)

      if @build_path == Rage.root.join("public")
        raise ArgumentError, "build_path cannot be set to public/; use a nested directory instead, e.g., public/dist"
      end
    end

    # Returns the dev server configuration.
    #
    # @return [DevServer] the dev server configuration object
    def dev_server
      @dev_server ||= DevServer.new
    end

    ##
    # Stores configuration for the Vite development server.
    #
    class DevServer
      # @return [String] the hostname for the Vite dev server (default: "localhost")
      attr_accessor :host

      # @return [Integer] the port for the Vite dev server (default: 5173)
      attr_accessor :port

      # @private
      def initialize
        @host = "localhost"
        @port = 5173
      end
    end
  end
end
