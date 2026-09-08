# frozen_string_literal: true

require "net/http"

module Inertia
  module SSR
    ##
    # HTTP client for communicating with the SSR server.
    #
    # Sends page data to the SSR server and receives rendered HTML
    # containing the `head` and `body` fragments.
    #
    class Client
      class << self
        # Renders the Inertia page data on the SSR server.
        #
        # @param data [Hash] the Inertia page object to render
        # @return [Hash] parsed response containing "head" and "body" keys
        def render(data)
          response = begin
            Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 1, read_timeout: 1) do |http|
              http.post(uri.request_uri, data.to_json, "Content-Type" => "application/json")
            end
          rescue => e
            raise Inertia::SSRServerError, e
          end

          unless response.code == "200"
            raise Inertia::SSRServerError, "Request failed with status #{response.code}: #{response.body}"
          end

          JSON.parse(response.body)
        end

        private

        # Returns the URI for the SSR endpoint.
        #
        # In development, uses the Vite dev server's SSR endpoint.
        # In production, uses the configured {Configuration::Ssr#url}.
        #
        # @return [URI] the SSR server URI
        def uri
          @uri ||= if Rage.env.development?
            dev_server_config = Inertia.config.dev_server
            URI("http://#{dev_server_config.host}:#{dev_server_config.port}/__inertia_ssr")
          else
            uri = URI(Inertia.config.ssr.url)
            uri.path = "/render" if uri.path.empty? || uri.path == "/"
            uri
          end
        end
      end # class << self
    end
  end
end
