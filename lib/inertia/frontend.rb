# frozen_string_literal: true

require "digest"
require "net/http"

module Inertia
  ##
  # Manages frontend asset integration for Inertia responses.
  #
  class Frontend
    class << self
      # Returns the root directory of the frontend application.
      #
      # Uses {Configuration#frontend_path} if set, otherwise searches for a
      # Vite config file in common locations to determine where the frontend
      # source lives.
      #
      # @return [Pathname] path to the frontend root directory
      # @raise [RuntimeError] if no Vite config file is found
      def root
        @root ||= Inertia.config.frontend_path || begin
          vite_config = Rage.root.glob(["*/vite.config.{js,ts,mjs,mts}", "app/*/vite.config.{js,ts,mjs,mts}"]).first
          raise "Vite config not found" unless vite_config

          vite_config.dirname
        end
      end

      # Returns the directory containing built frontend assets.
      #
      # Uses {Configuration#build_path} if set, otherwise defaults to the
      # `dist` directory inside the frontend root.
      #
      # @return [Pathname] path to the build output directory
      def dist
        @dist ||= Inertia.config.build_path || root.join("dist")
      end

      # Returns a version identifier for the frontend assets.
      #
      # Computes an MD5 hash of the Vite manifest or index.html to detect
      # when assets have changed, enabling Inertia's asset versioning.
      #
      # @return [String] MD5 hex digest of the manifest file
      # @raise [RuntimeError] if no manifest or index.html is found in build path
      def version
        @version ||= begin
          manifest = dist.glob([".vite/manifest.json", "index.html"]).first
          Digest::MD5.file(manifest.to_s).hexdigest if manifest
        end
      end

      # Returns the command prefix for executing npm packages.
      #
      # Detects the package manager by checking for lock files and returns
      # the appropriate command to run package binaries.
      #
      # @return [String] command prefix (e.g., "npx", "pnpm exec", "yarn")
      # @raise [RuntimeError] if no supported package manager is detected
      def package_runner
        @package_runner ||= if root.join("package-lock.json").exist?
          "npx"
        elsif root.join("pnpm-lock.yaml").exist?
          "pnpm exec"
        elsif root.join("bun.lockb").exist? || root.join("bun.lock").exist?
          "bun x --bun"
        elsif root.join("yarn.lock").exist?
          "yarn"
        elsif root.join("deno.lock").exist?
          "deno x"
        else
          raise "No supported package manager detected"
        end

        @package_runner
      end

      # Renders the HTML layout with the Inertia page object embedded.
      #
      # In development, it fetches the layout from the Vite dev server and
      # rewrites relative asset paths to absolute URLs. In production, it
      # reads the pre-built layout from disk and caches it.
      #
      # @param data [Hash] the Inertia page object to embed
      # @return [String] HTML document with page data injected
      def render_layout(data)
        if Rage.env.development?
          build_dynamic_layout(data)
        else
          build_static_layout(data)
        end
      end

      private

      # Fetches the layout from Vite dev server and rewrites asset URLs.
      #
      # Transforms relative paths in src/href attributes and ES module imports
      # to point to the Vite dev server.
      #
      # @param data [Hash] the Inertia page object to embed
      # @return [String] HTML with rewritten URLs and page data
      def build_dynamic_layout(data)
        config = Inertia.config.dev_server
        dev_server_url = "http://#{config.host}:#{config.port}"

        layout = Net::HTTP.get(URI(dev_server_url))

        layout.gsub!(/(src|href)=(["'])\/([^"']+)\2/) do
          "#{$1}=\"#{dev_server_url}/#{$3}\""
        end

        layout.gsub!(/from\s*(["'])\/([^"']+)\1/) do
          "from \"#{dev_server_url}/#{$2}\""
        end

        inject_page_data(layout, data)
      end

      # Returns the cached static layout with page data.
      #
      # @param data [Hash] the Inertia page object to embed
      # @return [String] HTML with page data injected
      # @raise [RuntimeError] if index.html does not exist in build path
      def build_static_layout(data)
        @layout ||= begin
          layout = dist.join("index.html")
          raise "Production layout not found at #{layout}. Ensure the frontend has been built" unless layout.exist?
          layout.read
        end

        inject_page_data(@layout, data)
      end

      # Injects the page object JSON into the HTML body.
      #
      # @param layout [String] the HTML layout template
      # @param data [Hash] the Inertia page object
      # @return [String] HTML with page data script tag inserted after <body>
      def inject_page_data(layout, data)
        layout.sub "<body>", <<~HTML
          <body>
            <script data-page="app" type="application/json">#{data.to_json}</script>
        HTML
      end
    end
  end
end
