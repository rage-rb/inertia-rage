# frozen_string_literal: true

module Inertia
  module Middleware
    ##
    # Serves built Vite assets in production using `x-sendfile` headers.
    #
    class Assets
      EMPTY_BODY = [].freeze

      def initialize(app)
        @app = app
        @assets_root = Frontend.root.join("dist/assets").realpath.to_s
      end

      def call(env)
        method = env["REQUEST_METHOD"]
        return @app.call(env) unless method == "GET" || method == "HEAD"

        raw_path = env["PATH_INFO"]
        return @app.call(env) unless raw_path.start_with?("/assets/")

        [
          200,
          {
            "x-sendfile" => raw_path.delete_prefix("/assets"),
            "x-sendfile-root" => @assets_root,
            "cache-control" => "public, max-age=31536000, immutable"
          },
          EMPTY_BODY
        ]
      end
    end
  end
end
