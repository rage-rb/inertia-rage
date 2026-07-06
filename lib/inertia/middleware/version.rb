# frozen_string_literal: true

module Inertia
  module Middleware
    ##
    # Rack middleware that enforces Inertia asset version consistency.
    #
    # For GET requests carrying `X-Inertia-Version`, compares the client version
    # with {Frontend.version}. A mismatch returns `409` with `X-Inertia-Location`,
    # prompting the client to reload the current URL with the latest assets.
    #
    class Version
      def initialize(app)
        @app = app
        @server_version = Frontend.version
      end

      def call(env)
        return @app.call(env) unless env["REQUEST_METHOD"] == "GET"

        client_version = env["HTTP_X_INERTIA_VERSION"]

        if client_version.nil? || client_version == @server_version
          @app.call(env)
        else
          [409, { "x-inertia-location" => Rack::Request.new(env).url }, []]
        end
      end
    end
  end
end
