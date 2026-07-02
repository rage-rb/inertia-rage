module Inertia
  ##
  # A daemon that runs the Vite development server alongside the Rage process.
  #
  class ViteDevServer < Rage::Daemon
    def perform
      command = "#{Frontend.package_runner} vite dev --clearScreen false"
      pid = Process.spawn(command, chdir: Frontend.root)
      Process.wait(pid)

      # Vite child process sometimes receives a shutdown signal first. The supervisor sees that
      # the Vite process has exited and schedules a restart before Rage processes its own shutdown.
      # The delay allows Rage to handle the signal, stop supervision, and avoid a confusing log message.
      sleep 0.1
    end
  end
end
