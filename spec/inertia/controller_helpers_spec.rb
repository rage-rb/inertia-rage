# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::ControllerHelpers do
  let(:controller_class) do
    Class.new do
      include Inertia::ControllerHelpers

      attr_reader :headers, :status
      attr_reader :request, :params

      def initialize
        @headers = {}
        @status = nil
      end

      def head(status)
        @status = status
      end
    end
  end

  let(:request) { double(get?: is_get, post?: is_post, env: { "HTTP_REFERER" => referer }) }
  let(:is_get) { false }
  let(:is_post) { false }
  let(:referer) { "https://example.com/previous" }
  let(:controller) { controller_class.new }

  before do
    allow(controller).to receive(:request).and_return(request)
  end

  describe "#redirect_to" do
    context "with external: true" do
      it "sets the X-Inertia-Location header" do
        controller.redirect_to("https://external.com", external: true)

        expect(controller.headers["x-inertia-location"]).to eq("https://external.com")
      end

      it "responds with 409 status" do
        controller.redirect_to("https://external.com", external: true)

        expect(controller.status).to eq(409)
      end
    end

    context "with a GET request" do
      let(:is_get) { true }
      let(:is_post) { false }

      it "responds with 302 status" do
        controller.redirect_to("/dashboard")

        expect(controller.status).to eq(302)
      end

      it "sets the location header" do
        controller.redirect_to("/dashboard")

        expect(controller.headers["location"]).to eq("/dashboard")
      end

      it "doesn't set the X-Inertia-Location header" do
        controller.redirect_to("/dashboard")

        expect(controller.headers["x-inertia-location"]).to be_nil
      end
    end

    context "with a POST request" do
      let(:is_get) { false }
      let(:is_post) { true }

      it "responds with 302 status" do
        controller.redirect_to("/dashboard")

        expect(controller.status).to eq(302)
      end

      it "sets the location header" do
        controller.redirect_to("/dashboard")

        expect(controller.headers["location"]).to eq("/dashboard")
      end

      it "doesn't set the X-Inertia-Location header" do
        controller.redirect_to("/dashboard")

        expect(controller.headers["x-inertia-location"]).to be_nil
      end
    end

    context "with a PUT/PATCH/DELETE request" do
      let(:is_get) { false }
      let(:is_post) { false }

      it "responds with 303 status" do
        controller.redirect_to("/dashboard")

        expect(controller.status).to eq(303)
      end

      it "sets the location header" do
        controller.redirect_to("/dashboard")

        expect(controller.headers["location"]).to eq("/dashboard")
      end

      it "doesn't set the X-Inertia-Location header" do
        controller.redirect_to("/dashboard")

        expect(controller.headers["x-inertia-location"]).to be_nil
      end
    end

    context "with location :back" do
      it "sets the location header to the referer" do
        controller.redirect_to(:back)

        expect(controller.headers["location"]).to eq(referer)
      end

      context "with a GET request" do
        let(:is_get) { true }
        let(:is_post) { false }

        it "responds with 302 status" do
          controller.redirect_to(:back)

          expect(controller.status).to eq(302)
        end
      end

      context "with a non-GET/POST request" do
        let(:is_get) { false }
        let(:is_post) { false }

        it "responds with 303 status" do
          controller.redirect_to(:back)

          expect(controller.status).to eq(303)
        end
      end
    end
  end

  describe "#append_info_to_payload" do
    let(:params) { { user_id: 1, action: "show" } }
    let(:controller) { controller_class.new }

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
end
