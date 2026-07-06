# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::Middleware::Version do
  subject { described_class.new(app) }

  let(:app) { double(call: :test_app_response) }

  before do
    allow(Inertia::Frontend).to receive(:version).and_return("abc123")
  end

  describe "#call" do
    context "with a non-GET request" do
      it "passes through POST requests" do
        env = { "REQUEST_METHOD" => "POST", "HTTP_X_INERTIA_VERSION" => "different" }

        expect(subject.call(env)).to eq(:test_app_response)
      end

      it "passes through PUT requests" do
        env = { "REQUEST_METHOD" => "PUT", "HTTP_X_INERTIA_VERSION" => "different" }

        expect(subject.call(env)).to eq(:test_app_response)
      end

      it "passes through DELETE requests" do
        env = { "REQUEST_METHOD" => "DELETE", "HTTP_X_INERTIA_VERSION" => "different" }

        expect(subject.call(env)).to eq(:test_app_response)
      end
    end

    context "with a GET request without X-Inertia-Version header" do
      it "passes through to the app" do
        env = { "REQUEST_METHOD" => "GET" }

        expect(subject.call(env)).to eq(:test_app_response)
      end
    end

    context "with a GET request with matching X-Inertia-Version" do
      it "passes through to the app" do
        env = { "REQUEST_METHOD" => "GET", "HTTP_X_INERTIA_VERSION" => "abc123" }

        expect(subject.call(env)).to eq(:test_app_response)
      end
    end

    context "with a GET request with mismatched X-Inertia-Version" do
      it "returns 409 Conflict with X-Inertia-Location" do
        env = {
          "REQUEST_METHOD" => "GET",
          "HTTP_X_INERTIA_VERSION" => "old-version",
          "rack.url_scheme" => "https",
          "HTTP_HOST" => "example.com",
          "PATH_INFO" => "/dashboard",
          "QUERY_STRING" => ""
        }

        status, headers, body = subject.call(env)

        expect(status).to eq(409)
        expect(headers["x-inertia-location"]).to eq("https://example.com/dashboard")
        expect(body).to be_empty

        expect(app).not_to have_received(:call)
      end

      it "preserves query parameters in the redirect URL" do
        env = {
          "REQUEST_METHOD" => "GET",
          "HTTP_X_INERTIA_VERSION" => "old-version",
          "rack.url_scheme" => "https",
          "HTTP_HOST" => "example.com",
          "PATH_INFO" => "/users",
          "QUERY_STRING" => "page=2&sort=name"
        }

        _, headers, _ = subject.call(env)

        expect(headers["x-inertia-location"]).to eq("https://example.com/users?page=2&sort=name")
      end
    end
  end
end
