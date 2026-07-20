# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::Renderer do
  let(:request) { double(fullpath: "/users", env: {}) }
  let(:controller_class) { double(name: "UsersController") }
  let(:action_name) { "index" }
  let(:controller) do
    double(request:, headers: {}, action_name:, inertia_shared_data: nil, class: controller_class)
  end

  let(:context) { instance_double(Inertia::RequestContext) }
  let(:builder) { instance_double(Inertia::ProtocolBuilder) }
  let(:page_data) { { component: "Users/Index", url: "/users", props: {} } }

  before do
    allow(Inertia::RequestContext).to receive(:new).and_return(context)
    allow(Inertia::ProtocolBuilder).to receive(:new).and_return(builder)
    allow(builder).to receive(:call).and_return(page_data)
    allow(Inertia::Frontend).to receive(:render_layout).and_return("<html></html>")
  end

  describe "component name" do
    it "uses the explicit component name" do
      described_class.call("Dashboard/Home", { user: "Jonathan" }, controller:)

      expect(Inertia::ProtocolBuilder).to have_received(:new).with(
        "Dashboard/Home",
        { user: "Jonathan" },
        context: context,
      )
    end

    context "with namespaced controller" do
      let(:controller_class) { double("ControllerClass", name: "Admin::UsersController") }

      it "infers component name from controller and action" do
        described_class.call({ user: "Jonathan" }, nil, controller:)

        expect(Inertia::ProtocolBuilder).to have_received(:new).with(
          "Admin/Users/Index",
          { user: "Jonathan" },
          context: context,
        )
      end
    end

    it "capitalizes the action name in inferred components" do
      described_class.call({ items: [] }, nil, controller:)

      expect(Inertia::ProtocolBuilder).to have_received(:new).with(
        "Users/Index",
        { items: [] },
        context: context,
      )
    end

    context "with multi-word action name" do
      let(:action_name) { "edit_profile" }

      it "infers component name from controller and action" do
        described_class.call({ user: "Jonathan" }, nil, controller:)

        expect(Inertia::ProtocolBuilder).to have_received(:new).with(
          "Users/EditProfile",
          { user: "Jonathan" },
          context: context,
        )
      end
    end

    it "raises when using inferred component with explicit props" do
      expect {
        described_class.call({ user: "Jonathan" }, { extra: "data" }, controller:)
      }.to raise_error(ArgumentError, "props must be nil when using inferred component names")
    end
  end

  describe "RequestContext" do
    it "creates context with request and component name" do
      described_class.call("Users/Index", {}, controller:)

      expect(Inertia::RequestContext).to have_received(:new).with(request, component: "Users/Index")
    end

    it "creates context with inferred component name" do
      described_class.call({ items: [] }, nil, controller:)

      expect(Inertia::RequestContext).to have_received(:new).with(request, component: "Users/Index")
    end
  end

  describe "ProtocolBuilder" do
    it "passes the context to the builder" do
      described_class.call("Users/Index", { users: [] }, controller:)

      expect(Inertia::ProtocolBuilder).to have_received(:new).with(
        "Users/Index",
        { users: [] },
        context: context,
      )
    end

    it "calls the builder to get the page data" do
      described_class.call("Users/Index", {}, controller:)

      expect(builder).to have_received(:call)
    end
  end

  describe "XHR requests" do
    before do
      allow(request).to receive(:env).and_return({ "HTTP_X_INERTIA" => "true" })
    end

    it "returns JSON response from page data" do
      result = described_class.call("Users/Index", {}, controller:)

      expect(result).to eq(page_data.to_json)
    end

    it "sets the vary header" do
      described_class.call("Users/Index", {}, controller:)

      expect(controller.headers["vary"]).to eq("x-inertia")
    end

    it "sets the x-inertia header" do
      described_class.call("Users/Index", {}, controller:)

      expect(controller.headers["x-inertia"]).to eq("true")
    end

    it "sets the content-type header to JSON" do
      described_class.call("Users/Index", {}, controller:)

      expect(controller.headers["content-type"]).to eq("application/json; charset=utf-8")
    end

    it "does not call Frontend.render_layout" do
      described_class.call("Users/Index", {}, controller:)

      expect(Inertia::Frontend).not_to have_received(:render_layout)
    end
  end

  describe "initial page load" do
    it "delegates to Frontend.render_layout with page data" do
      allow(Inertia::Frontend).to receive(:render_layout).and_return("<html>rendered</html>")

      result = described_class.call("Users/Index", {}, controller:)

      expect(result).to eq("<html>rendered</html>")
      expect(Inertia::Frontend).to have_received(:render_layout).with(page_data)
    end

    it "sets the content-type header to HTML" do
      described_class.call("Users/Index", {}, controller:)

      expect(controller.headers["content-type"]).to eq("text/html; charset=utf-8")
    end

    it "does not set Inertia-specific headers" do
      described_class.call("Users/Index", {}, controller:)

      expect(controller.headers).not_to have_key("vary")
      expect(controller.headers).not_to have_key("x-inertia")
    end
  end
end
