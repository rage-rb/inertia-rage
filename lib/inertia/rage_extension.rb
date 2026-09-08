# frozen_string_literal: true

module Inertia
  ##
  # Integrates the gem with Rage - the extension serves as the glue between Inertia
  # and Rage, configuring rendering, asset handling, and controller helpers.
  #
  class RageExtension < Rage::Extension
    configure do
      # Register custom renderer to enable `render inertia: ...` syntax in controllers
      config.renderer(:inertia) do |component, props: {}|
        Renderer.call(component, props, controller: self)
      end

      # Automatically start Vite dev server in development mode
      config.daemons << ViteDevServer if Rage.env.development?

      # Automatically start the SSR server
      after_initialize do
        config.daemons << SSR::Server if Inertia.config.ssr.enabled && Inertia.config.ssr.local? && !Rage.env.development?
      end

      # In production, serve prebuilt static assets via the public file server and Assets middleware
      unless Rage.env.development?
        config.public_file_server.enabled = true

        config.middleware.allow_outside_request_fiber! do
          config.middleware.insert_before 0, Middleware::Assets
        end
      end

      # Enable automatic generation of `new` and `edit` routes via resource helpers
      config.router.form_actions = true
      # Verify asset version consistency between client and server
      config.middleware.use Middleware::Version
    end

    # Prebuild frontend assets before launching the server in production
    before_server_start do
      if Inertia.config.build_on_start?
        puts "INFO: Building frontend"
        puts ""
        system("#{Frontend.package_runner} vite build", chdir: Frontend.root) || abort("ERROR: Frontend build failed")

        if Inertia.config.ssr.enabled
          if Inertia.config.ssr.local?
            out_dir = Frontend.ssr_dist.relative_path_from(Frontend.root)
            system("#{Frontend.package_runner} vite build --ssr --outDir #{out_dir}", chdir: Frontend.root) || abort("ERROR: SSR build failed")
          else
            puts "INFO: SSR server is remote - skipping SSR build"
          end
        end
      end
    end
  end
end
