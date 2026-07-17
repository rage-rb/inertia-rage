# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::ControllerHelpers do
  let(:controller_class) do
    Class.new(RageController::API) do
      include Inertia::ControllerHelpers
      extend Inertia::ControllerHelpers::ClassMethods
    end
  end

  let(:controller) { controller_class.new(nil, nil) }

  describe ".inertia_share" do
    it "calls before_action" do
      expect(controller_class).to receive(:before_action).with(only: :index)

      controller_class.inertia_share(only: :index) { { key: "value" } }
    end

    it "initializes inertia_shared_data with nil" do
      expect(controller.inertia_shared_data).to be_nil
    end

    it "sets inertia_shared_data from the block result" do
      actions = controller_class.inertia_share { { user: "John" } }
      method_name = actions[-1][:name]

      controller.send(method_name)

      expect(controller.inertia_shared_data).to eq({ user: "John" })
    end

    it "merges data from multiple inertia_share calls" do
      actions1 = controller_class.inertia_share { { user: "John" } }
      actions2 = controller_class.inertia_share { { locale: "en" } }
      method_name1 = actions1[-2][:name]
      method_name2 = actions2[-1][:name]

      controller.send(method_name1)
      controller.send(method_name2)

      expect(controller.inertia_shared_data).to eq({ user: "John", locale: "en" })
    end

    it "later calls override earlier values for the same key" do
      actions1 = controller_class.inertia_share { { user: "John" } }
      actions2 = controller_class.inertia_share { { user: "Jane" } }
      method_name1 = actions1[-2][:name]
      method_name2 = actions2[-1][:name]

      controller.send(method_name1)
      controller.send(method_name2)

      expect(controller.inertia_shared_data).to eq({ user: "Jane" })
    end

    it "evaluates the block in the controller instance context" do
      controller_class.define_method(:current_user) { "Alice" }
      actions = controller_class.inertia_share { { user: current_user } }
      method_name = actions[-1][:name]

      controller.send(method_name)

      expect(controller.inertia_shared_data).to eq({ user: "Alice" })
    end

    it "raises ArgumentError when no block is given" do
      expect {
        controller_class.inertia_share(only: :index)
      }.to raise_error(ArgumentError, "inertia_share requires a block")
    end

    it "does nothing when the block returns nil" do
      actions = controller_class.inertia_share { nil }
      method_name = actions[-1][:name]

      controller.send(method_name)

      expect(controller.inertia_shared_data).to be_nil
    end

    it "preserves existing data when the block returns nil" do
      actions1 = controller_class.inertia_share { { user: "John" } }
      actions2 = controller_class.inertia_share { nil }
      method_name1 = actions1[-2][:name]
      method_name2 = actions2[-1][:name]

      controller.send(method_name1)
      controller.send(method_name2)

      expect(controller.inertia_shared_data).to eq({ user: "John" })
    end
  end

  # Relies on Rage private API
  let(:response_status) { controller.__status }
  let(:response_headers) { controller.__headers }
  let(:response_body) { controller.__body[0] }

  describe "#redirect_to" do
    let(:is_get) { false }
    let(:is_post) { false }
    let(:referer) { "https://example.com/previous" }
    let(:request) { double(get?: is_get, post?: is_post, env: { "HTTP_REFERER" => referer }) }

    before do
      allow(controller).to receive(:request).and_return(request)
    end

    context "with external: true" do
      it "sets the X-Inertia-Location header" do
        controller.redirect_to("https://external.com", external: true)

        expect(response_headers["x-inertia-location"]).to eq("https://external.com")
      end

      it "responds with 409 status" do
        controller.redirect_to("https://external.com", external: true)

        expect(response_status).to eq(409)
      end
    end

    context "with a GET request" do
      let(:is_get) { true }
      let(:is_post) { false }

      it "responds with 302 status" do
        controller.redirect_to("/dashboard")

        expect(response_status).to eq(302)
      end

      it "sets the location header" do
        controller.redirect_to("/dashboard")

        expect(response_headers["location"]).to eq("/dashboard")
      end

      it "doesn't set the X-Inertia-Location header" do
        controller.redirect_to("/dashboard")

        expect(response_headers["x-inertia-location"]).to be_nil
      end
    end

    context "with a POST request" do
      let(:is_get) { false }
      let(:is_post) { true }

      it "responds with 302 status" do
        controller.redirect_to("/dashboard")

        expect(response_status).to eq(302)
      end

      it "sets the location header" do
        controller.redirect_to("/dashboard")

        expect(response_headers["location"]).to eq("/dashboard")
      end

      it "doesn't set the X-Inertia-Location header" do
        controller.redirect_to("/dashboard")

        expect(response_headers["x-inertia-location"]).to be_nil
      end
    end

    context "with a PUT/PATCH/DELETE request" do
      let(:is_get) { false }
      let(:is_post) { false }

      it "responds with 303 status" do
        controller.redirect_to("/dashboard")

        expect(response_status).to eq(303)
      end

      it "sets the location header" do
        controller.redirect_to("/dashboard")

        expect(response_headers["location"]).to eq("/dashboard")
      end

      it "doesn't set the X-Inertia-Location header" do
        controller.redirect_to("/dashboard")

        expect(response_headers["x-inertia-location"]).to be_nil
      end
    end

  end

  describe "#redirect_back" do
    let(:referer) { "https://example.com/previous" }
    let(:request) { double(get?: false, post?: false, env: { "HTTP_REFERER" => referer }) }

    before do
      allow(controller).to receive(:request).and_return(request)
    end

    context "with a referer" do
      it "redirects to the referer" do
        controller.redirect_back(fallback_location: "/fallback")

        expect(response_headers["location"]).to eq(referer)
      end
    end

    context "without a referer" do
      let(:referer) { nil }

      it "redirects to the fallback location" do
        controller.redirect_back(fallback_location: "/fallback")

        expect(response_headers["location"]).to eq("/fallback")
      end
    end

    context "with external: true" do
      it "sets the X-Inertia-Location header" do
        controller.redirect_back(fallback_location: "/fallback", external: true)

        expect(response_headers["x-inertia-location"]).to eq(referer)
      end

      it "responds with 409 status" do
        controller.redirect_back(fallback_location: "/fallback", external: true)

        expect(response_status).to eq(409)
      end
    end
  end

  describe "#redirect_back_or_to" do
    let(:referer) { "https://example.com/previous" }
    let(:request) { double(get?: false, post?: false, env: { "HTTP_REFERER" => referer }) }

    before do
      allow(controller).to receive(:request).and_return(request)
    end

    context "with a referer" do
      it "redirects to the referer" do
        controller.redirect_back_or_to("/fallback")

        expect(response_headers["location"]).to eq(referer)
      end

      it "responds with 303 status for non-GET/POST requests" do
        controller.redirect_back_or_to("/fallback")

        expect(response_status).to eq(303)
      end
    end

    context "without a referer" do
      let(:referer) { nil }

      it "redirects to the fallback location" do
        controller.redirect_back_or_to("/fallback")

        expect(response_headers["location"]).to eq("/fallback")
      end
    end

    context "with external: true" do
      it "sets the X-Inertia-Location header" do
        controller.redirect_back_or_to("/fallback", external: true)

        expect(response_headers["x-inertia-location"]).to eq(referer)
      end

      it "responds with 409 status" do
        controller.redirect_back_or_to("/fallback", external: true)

        expect(response_status).to eq(409)
      end
    end
  end

  describe "#append_info_to_payload" do
    let(:params) { { user_id: 1, action: "show" } }

    before do
      allow(controller).to receive(:params).and_return(params)
    end

    it "is defined" do
      expect(controller.respond_to?(:append_info_to_payload, true)).to be(true)
    end

    context "in development environment" do
      before do
        allow(Rage).to receive(:env).and_return(double(development?: true))
      end

      it "appends params to the context" do
        context = {}
        controller.send(:append_info_to_payload, context)

        expect(context[:params]).to eq(params)
      end
    end

    context "in non-development environment" do
      before do
        allow(Rage).to receive(:env).and_return(double(development?: false))
      end

      it "does not append params to the context" do
        context = {}
        controller.send(:append_info_to_payload, context)

        expect(context).to be_empty
      end
    end
  end

  describe "#protect_from_csrf" do
    let(:request_method) { "POST" }
    let(:sec_fetch_site) { nil }
    let(:origin) { nil }
    let(:http_host) { "example.com" }

    let(:request) do
      double(
        get?: false,
        post?: true,
        env: {
          "REQUEST_METHOD" => request_method,
          "HTTP_SEC_FETCH_SITE" => sec_fetch_site,
          "HTTP_ORIGIN" => origin,
          "HTTP_HOST" => http_host
        }
      )
    end

    before do
      allow(controller).to receive(:request).and_return(request)
    end

    context "with safe methods" do
      %w[GET HEAD OPTIONS].each do |method|
        context "when request method is #{method}" do
          let(:request_method) { method }

          it "allows the request" do
            expect(controller).not_to receive(:render)

            controller.send(:protect_from_csrf)
          end
        end
      end
    end

    context "with Sec-Fetch-Site header" do
      context "when same-origin" do
        let(:sec_fetch_site) { "same-origin" }

        it "allows the request" do
          expect(controller).not_to receive(:render)

          controller.send(:protect_from_csrf)
        end
      end

      context "when none" do
        let(:sec_fetch_site) { "none" }

        it "allows the request" do
          expect(controller).not_to receive(:render)

          controller.send(:protect_from_csrf)
        end
      end

      context "when cross-site" do
        let(:sec_fetch_site) { "cross-site" }

        it "rejects the request" do
          controller.send(:protect_from_csrf)

          expect(response_status).to eq(403)
          expect(response_body).to eq("CSRF rejected")
        end
      end

      context "when same-site" do
        let(:sec_fetch_site) { "same-site" }

        it "rejects the request" do
          controller.send(:protect_from_csrf)

          expect(response_status).to eq(403)
          expect(response_body).to eq("CSRF rejected")
        end
      end
    end

    context "without Sec-Fetch-Site header (fallback to Origin)" do
      let(:sec_fetch_site) { nil }

      context "when Origin header is not present" do
        let(:origin) { nil }

        it "allows the request" do
          expect(controller).not_to receive(:render)

          controller.send(:protect_from_csrf)
        end
      end

      context "when Origin matches Host" do
        let(:origin) { "https://example.com" }
        let(:http_host) { "example.com" }

        it "allows the request" do
          expect(controller).not_to receive(:render)

          controller.send(:protect_from_csrf)
        end
      end

      context "when Origin matches Host with port" do
        let(:origin) { "https://localhost:3000" }
        let(:http_host) { "localhost:3000" }

        it "allows the request" do
          expect(controller).not_to receive(:render)

          controller.send(:protect_from_csrf)
        end
      end

      context "when Origin host matches but port differs" do
        let(:origin) { "https://localhost:3000" }
        let(:http_host) { "localhost:4000" }

        it "rejects the request" do
          controller.send(:protect_from_csrf)

          expect(response_status).to eq(403)
        end
      end

      context "when Origin does not match Host" do
        let(:origin) { "https://evil.com" }
        let(:http_host) { "example.com" }

        it "rejects the request" do
          controller.send(:protect_from_csrf)

          expect(response_status).to eq(403)
          expect(response_body).to eq("CSRF rejected")
        end
      end

      context "when Origin is invalid" do
        let(:origin) { "not a valid uri" }

        it "rejects the request" do
          controller.send(:protect_from_csrf)

          expect(response_status).to eq(403)
          expect(response_body).to eq("CSRF rejected")
        end
      end
    end
  end
end
