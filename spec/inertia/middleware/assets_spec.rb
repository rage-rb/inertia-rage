# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::Middleware::Assets do
  subject { described_class.new(app) }

  let(:app) { double(call: :test_app_response) }
  let(:mock_path) { double(realpath: double(to_s: "/var/www/app/frontend/dist/assets")) }

  before do
    allow(Inertia::Frontend).to receive(:dist).and_return(double(join: mock_path))
  end

  describe "#call" do
    context "with non-GET/HEAD requests" do
      it "passes through POST requests" do
        env = { "REQUEST_METHOD" => "POST", "PATH_INFO" => "/assets/main.js" }

        expect(subject.call(env)).to eq(:test_app_response)
      end

      it "passes through PUT requests" do
        env = { "REQUEST_METHOD" => "PUT", "PATH_INFO" => "/assets/main.js" }

        expect(subject.call(env)).to eq(:test_app_response)
      end

      it "passes through DELETE requests" do
        env = { "REQUEST_METHOD" => "DELETE", "PATH_INFO" => "/assets/main.js" }

        expect(subject.call(env)).to eq(:test_app_response)
      end
    end

    context "with non-asset paths" do
      it "passes through GET requests to other paths" do
        env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/users" }

        expect(subject.call(env)).to eq(:test_app_response)
      end

      it "passes through HEAD requests to other paths" do
        env = { "REQUEST_METHOD" => "HEAD", "PATH_INFO" => "/api/data" }

        expect(subject.call(env)).to eq(:test_app_response)
      end
    end

    context "with GET requests to /assets/" do
      it "returns 200 with sendfile headers" do
        env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/assets/main-abc123.js" }

        status, headers, body = subject.call(env)

        expect(status).to eq(200)
        expect(headers["x-sendfile"]).to eq("/main-abc123.js")
        expect(headers["x-sendfile-root"]).to eq("/var/www/app/frontend/dist/assets")
        expect(headers["cache-control"]).to eq("public, max-age=31536000, immutable")
        expect(body).to be_empty

        expect(app).not_to have_received(:call)
      end

      it "handles nested asset paths" do
        env = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/assets/chunks/vendor-def456.js" }

        _, headers, _ = subject.call(env)

        expect(headers["x-sendfile"]).to eq("/chunks/vendor-def456.js")
      end
    end

    context "with HEAD requests to /assets/" do
      it "returns 200 with sendfile headers" do
        env = { "REQUEST_METHOD" => "HEAD", "PATH_INFO" => "/assets/style-xyz789.css" }

        status, headers, body = subject.call(env)

        expect(status).to eq(200)
        expect(headers["x-sendfile"]).to eq("/style-xyz789.css")
        expect(headers["x-sendfile-root"]).to eq("/var/www/app/frontend/dist/assets")
        expect(body).to be_empty
      end
    end
  end
end
