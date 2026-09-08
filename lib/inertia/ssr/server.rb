# frozen_string_literal: true

module Inertia
  module SSR
    ##
    # Background daemon that runs the Node.js SSR server.
    #
    class Server < Rage::Daemon
      def perform
        puts "INFO: Starting SSR server"

        ssr_bundle = Frontend.ssr_dist.glob("*.{js,mjs}").first

        unless ssr_bundle&.exist?
          Rage.logger.fatal("Could not start SSR server - bundle not found")
          return Rage::Daemon::Stop
        end

        @pid = Process.spawn("#{Frontend.runtime} #{ssr_bundle.relative_path_from(Frontend.root)}", chdir: Frontend.root)
        Process.wait(@pid)
      end

      def cleanup
        Process.kill("TERM", @pid) if @pid
      rescue Errno::ESRCH
      end
    end
  end
end
