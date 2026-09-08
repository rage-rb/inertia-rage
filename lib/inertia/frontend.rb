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
      # @raise [RuntimeError] if no Vite config file is found
      def dist
        @dist ||= Inertia.config.build_path || root.join("dist")
      end

      # Returns the directory containing built SSR assets.
      #
      # Uses {Configuration::Ssr#build_path} if set, otherwise defaults to
      # `dist/ssr` inside the frontend root.
      #
      # @return [Pathname] path to the build output directory
      # @raise [RuntimeError] if no Vite config file is found
      def ssr_dist
        @ssr_dist ||= Inertia.config.ssr.build_path || dist.join("ssr")
      end

      # Returns a version identifier for the frontend assets.
      #
      # Computes an MD5 hash of the Vite manifest or index.html to detect
      # when assets have changed, enabling Inertia's asset versioning.
      #
      # @return [String] MD5 hex digest of the manifest file
      # @raise [RuntimeError] if no Vite config file is found
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

      # Returns the JavaScript runtime command.
      #
      # Detects the runtime by checking for lock files and returns
      # the appropriate command to execute scripts.
      #
      # @return [String] runtime command (e.g., "node", "bun", "deno run")
      # @raise [RuntimeError] if no supported runtime is detected
      def runtime
        @runtime ||= if root.join("package-lock.json").exist?
          "node"
        elsif root.join("pnpm-lock.yaml").exist?
          "node"
        elsif root.join("bun.lockb").exist? || root.join("bun.lock").exist?
          "bun"
        elsif root.join("yarn.lock").exist?
          "node"
        elsif root.join("deno.lock").exist?
          "deno run --allow-net --allow-env"
        else
          raise "No supported JavaScript runtime detected"
        end
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

        retries = 0
        begin
          layout = Net::HTTP.get(URI(dev_server_url))
        rescue Errno::ECONNREFUSED, Errno::EBADF
          raise if (retries += 1) > 5
          sleep 0.2
          retry
        end

        layout.gsub!(/(src|href)=(["'])\/([^"']+)\2/) do
          "#{$1}=\"#{dev_server_url}/#{$3}\""
        end

        layout.gsub!(/from\s*(["'])\/([^"']+)\1/) do
          "from \"#{dev_server_url}/#{$2}\""
        end

        hydrate_layout(layout, data)
      end

      # Returns the cached static layout with page data.
      #
      # @param data [Hash] the Inertia page object to embed
      # @return [String] HTML with page data injected
      # @raise [RuntimeError] if index.html does not exist in build path
      def build_static_layout(data)
        @static_layout ||= begin
          layout = dist.join("index.html")
          raise "Production layout not found at #{layout}. Ensure the frontend has been built" unless layout.exist?
          layout.read
        end

        hydrate_layout(@static_layout, data)
      end

      def hydrate_layout(layout, data)
        if Inertia.config.ssr.enabled
          ssr_layout = inject_ssr_data(layout, data)
          return ssr_layout if ssr_layout
        end

        inject_page_data(layout, data)
      end

      def inject_ssr_data(layout, data)
        ssr_data = Inertia::SSR::Client.render(data)

        processed_layout = layout.sub(/<div\s[^>]*\bid=(["'])app\1[^>]*>\s*<\/div>/i) { ssr_data["body"] }

        if (head = ssr_data["head"]).any?
          processed_layout.sub!(/<head([^>]*)>/i) do |head_tag|
            <<~HTML
              #{head_tag}
                #{ssr_data["head"].join}
            HTML
          end
        end

        processed_layout

      rescue => e
        Rage.logger.error("SSR render failed", exception: e.message)
        Rage::Errors.report(e)
        nil
      end

      # Injects the page object JSON into the HTML body.
      #
      # @param layout [String] the HTML layout template
      # @param data [Hash] the Inertia page object
      # @return [String] HTML with page data script tag inserted after <body>
      def inject_page_data(layout, data)
        json_data = data.to_json
        json_data.gsub!("<", '\u003c') if json_data.include?("<")

        layout.sub(/<body([^>]*)>/i) do |body_tag|
          <<~HTML
            #{body_tag}
              <script data-page="app" type="application/json">#{json_data}</script>
          HTML
        end
      end
    end
  end
end
