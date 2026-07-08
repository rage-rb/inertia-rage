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

    # Include ControllerHelpers to add support for `redirect_to` and other Inertia-specific methods
    initializer "inertia.rage.controller_helpers" do
      RageController::API.include ControllerHelpers
    end

    # Prebuild frontend assets before launching the server in production
    before_server_start do
      unless Rage.env.development?
        puts "INFO: Building frontend"
        puts ""
        system("#{Frontend.package_runner} vite build", chdir: Frontend.root) || abort("ERROR: Frontend build failed")
      end
    end
  end
end
