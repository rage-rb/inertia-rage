# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::SSR::Client do
  around do |example|
    described_class.instance_variable_set(:@uri, nil)

    example.run

    described_class.instance_variable_set(:@uri, nil)
  end

  describe ".render" do
    let(:page_data) { { component: "Home", props: { user: "Jane" } } }
    let(:ssr_response) do
      {
        "head" => ["<title>Home</title>"],
        "body" => '<div id="app"><h1>Welcome Jane</h1></div>'
      }
    end

    before do
      allow(Rage).to receive(:env).and_return(double(development?: false))
    end

    it "sends page data as JSON to the SSR server" do
      http = instance_double(Net::HTTP)
      response = instance_double(Net::HTTPResponse, body: ssr_response.to_json)

      allow(Net::HTTP).to receive(:start).and_yield(http)

      expect(http).to receive(:post).with("/render", page_data.to_json).and_return(response)

      described_class.render(page_data)
    end

    it "returns parsed JSON response" do
      http = instance_double(Net::HTTP)
      response = instance_double(Net::HTTPResponse, body: ssr_response.to_json)

      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:post).and_return(response)

      result = described_class.render(page_data)

      expect(result).to eq(ssr_response)
    end

    it "includes the configured query string in the request target" do
      allow(Inertia.config.ssr).to receive(:url).and_return("https://ssr.example.com/render?token=secret")

      http = instance_double(Net::HTTP)
      response = instance_double(Net::HTTPResponse, body: ssr_response.to_json)

      allow(Net::HTTP).to receive(:start).and_yield(http)

      expect(http).to receive(:post).with("/render?token=secret", page_data.to_json).and_return(response)

      described_class.render(page_data)
    end

    it "uses SSL for https URLs" do
      allow(Inertia.config.ssr).to receive(:url).and_return("https://ssr.example.com")

      http = instance_double(Net::HTTP)
      response = instance_double(Net::HTTPResponse, body: ssr_response.to_json)
      allow(http).to receive(:post).and_return(response)

      expect(Net::HTTP).to receive(:start).with("ssr.example.com", 443, use_ssl: true, open_timeout: 1, read_timeout: 1).and_yield(http)

      described_class.render(page_data)
    end

    it "uses the unbracketed hostname for IPv6 URLs" do
      allow(Inertia.config.ssr).to receive(:url).and_return("http://[::1]:13714")

      http = instance_double(Net::HTTP)
      response = instance_double(Net::HTTPResponse, body: ssr_response.to_json)
      allow(http).to receive(:post).and_return(response)

      expect(Net::HTTP).to receive(:start).with("::1", 13714, use_ssl: false, open_timeout: 1, read_timeout: 1).and_yield(http)

      described_class.render(page_data)
    end
  end

  describe "uri" do
    context "in development" do
      before do
        allow(Rage).to receive(:env).and_return(double(development?: true))
      end

      it "uses the Vite dev server SSR endpoint" do
        allow(Inertia.config).to receive(:dev_server).and_return(double(host: "localhost", port: 5173))

        uri = described_class.send(:uri)

        expect(uri.to_s).to eq("http://localhost:5173/__inertia_ssr")
      end

      it "respects custom dev server configuration" do
        allow(Inertia.config).to receive(:dev_server).and_return(double(host: "0.0.0.0", port: 3000))

        uri = described_class.send(:uri)

        expect(uri.to_s).to eq("http://0.0.0.0:3000/__inertia_ssr")
      end
    end

    context "in production" do
      before do
        allow(Rage).to receive(:env).and_return(double(development?: false))
      end

      it "uses the configured SSR URL with /render path" do
        allow(Inertia.config.ssr).to receive(:url).and_return("http://localhost:13714")

        uri = described_class.send(:uri)

        expect(uri.to_s).to eq("http://localhost:13714/render")
      end

      it "adds /render when the configured SSR URL has a trailing slash" do
        allow(Inertia.config.ssr).to receive(:url).and_return("http://localhost:13714/")

        uri = described_class.send(:uri)

        expect(uri.to_s).to eq("http://localhost:13714/render")
      end

      it "preserves custom path in SSR URL" do
        allow(Inertia.config.ssr).to receive(:url).and_return("http://ssr.example.com/custom/path")

        uri = described_class.send(:uri)

        expect(uri.to_s).to eq("http://ssr.example.com/custom/path")
      end

      it "respects custom SSR URL" do
        allow(Inertia.config.ssr).to receive(:url).and_return("https://ssr.internal:8080")

        uri = described_class.send(:uri)

        expect(uri.to_s).to eq("https://ssr.internal:8080/render")
      end
    end
  end

end
