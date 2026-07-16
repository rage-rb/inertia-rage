# frozen_string_literal: true

module RspecSpecHelpers
  class TestController < RageController::API
    include Inertia::ControllerHelpers

    def index
      render inertia: "Users/Index", props: {
        "users" => [{ "id" => 1, "name" => "John" }, { "id" => 2, "name" => "Jane" }],
        "meta" => { "total" => 2 }
      }
    end

    def show
      render inertia: "Users/Show", props: {
        user: { id: 1, name: "John", email: "john@example.com" },
        permissions: Inertia.optional { %w[read write] },
        activity: Inertia.deferred { %w[login logout] }
      }
    end

    def plain
      render plain: "Hello, World!"
    end

    def json_response
      render json: { message: "Hello" }
    end

    def redirect_action
      redirect_to "/users/1"
    end

    def redirect_to_external
      redirect_to "https://example.com/callback", external: true
    end
  end

  Rage.routes.draw do
    root to: "rspec_spec_helpers/test#index"
    get "/users/:id", to: "rspec_spec_helpers/test#show"
    get "/plain", to: "rspec_spec_helpers/test#plain"
    get "/json", to: "rspec_spec_helpers/test#json_response"
    get "/redirect", to: "rspec_spec_helpers/test#redirect_action"
    get "/redirect_external", to: "rspec_spec_helpers/test#redirect_to_external"
  end
end

RSpec.describe "Inertia::RSpec", type: :request do
  before :context do
    Rage.instance_variable_set(:@root, Pathname.new(__dir__).expand_path)
    Rage.instance_variable_set(:@env, Rage::Env.new("test"))
    require "inertia/rspec"
  end

  after :context do
    Rage.instance_variable_set(:@root, nil)
    Rage.instance_variable_set(:@env, nil)
  end

  before do
    allow(Inertia::Frontend).to receive(:version)
    allow(Inertia::Frontend).to receive(:render_layout) do |data|
      "<html>#{data}</html>"
    end
  end

  describe "inertia response object" do
    it "returns component name" do
      get "/"
      expect(inertia.component).to eq("Users/Index")
    end

    it "returns props with symbolized keys" do
      get "/"
      expect(inertia.props).to eq({
        users: [{ id: 1, name: "John" }, { id: 2, name: "Jane" }],
        meta: { total: 2 }
      })
    end

    it "returns nested props with symbolized keys" do
      get "/users/1"
      expect(inertia.props[:user]).to eq({ id: 1, name: "John", email: "john@example.com" })
    end

    it "returns deferred props metadata" do
      get "/users/1"
      expect(inertia.deferred_props).to eq({ "default" => ["activity"] })
    end

    it "returns empty hash when no deferred props" do
      get "/"
      expect(inertia.deferred_props).to eq({})
    end
  end

  describe "non-inertia responses" do
    it "returns nil for plain text responses" do
      get "/plain"
      expect(inertia).to be_nil
    end

    it "returns nil for JSON responses" do
      get "/json"
      expect(inertia).to be_nil
    end
  end

  describe "partial reloads" do
    context "with :only option" do
      it "requests only specified props" do
        get "/users/1", inertia: { only: :user }

        expect(inertia.props.keys).to eq([:user])
        expect(inertia.props[:user]).to eq({ id: 1, name: "John", email: "john@example.com" })
      end

      it "requests multiple props with array" do
        get "/users/1", inertia: { only: [:user, :permissions] }

        expect(inertia.props.keys).to contain_exactly(:user, :permissions)
        expect(inertia.props[:permissions]).to eq(%w[read write])
      end

      it "overwrites previous response" do
        get "/users/1"
        get "/users/1", inertia: { only: :user }

        expect(inertia.props.keys).to eq([:user])
      end
    end

    context "with :except option" do
      it "excludes specified props" do
        get "/", inertia: { except: :meta }

        expect(inertia.props.keys).to eq([:users])
      end

      it "excludes multiple props with array" do
        get "/users/1", inertia: { except: [:permissions, :activity] }

        expect(inertia.props.keys).to eq([:user])
      end
    end

    context "loading deferred props" do
      it "loads deferred props when explicitly requested" do
        get "/users/1"
        expect(inertia.props.keys).to eq([:user])
        expect(inertia.deferred_props).to eq({ "default" => ["activity"] })

        get "/users/1", inertia: { only: :activity }
        expect(inertia.props[:activity]).to eq(%w[login logout])
      end
    end

    context "with invalid options" do
      it "raises ArgumentError for unknown options" do
        expect {
          get "/users/1", inertia: { unknown: :option }
        }.to raise_error(ArgumentError, /Unknown :inertia option/)
      end
    end
  end

  describe "redirect_to matcher" do
    context "with string expectation" do
      it "matches exact redirect location" do
        get "/redirect"
        expect(response).to redirect_to("/users/1")
      end

      it "fails when location does not match" do
        get "/redirect"
        expect(response).not_to redirect_to("/users/2")
      end

      it "provides failure message for non-matching location" do
        get "/redirect"
        expect {
          expect(response).to redirect_to("/wrong")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, 'expected response to be a redirect to "/wrong" but was a redirect to "/users/1"')
      end

      it "provides failure message when negated" do
        get "/redirect"
        expect {
          expect(response).not_to redirect_to("/users/1")
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, 'expected not to redirect to "/users/1", but did')
      end
    end

    context "with regex expectation" do
      it "matches redirect location against pattern" do
        get "/redirect"
        expect(response).to redirect_to(%r{/users/\d+})
      end

      it "fails when location does not match pattern" do
        get "/redirect"
        expect(response).not_to redirect_to(%r{/posts/\d+})
      end

      it "provides failure message for non-matching pattern" do
        get "/redirect"
        expect {
          expect(response).to redirect_to(%r{/posts/\d+})
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, 'expected response to be a redirect to //posts/\d+/ but was a redirect to "/users/1"')
      end

      it "provides failure message when negated" do
        get "/redirect"
        expect {
          expect(response).not_to redirect_to(%r{/users/\d+})
        }.to raise_error(RSpec::Expectations::ExpectationNotMetError, 'expected not to redirect to //users/\d+/, but did')
      end
    end

    context "with external: true" do
      it "matches full URL" do
        get "/redirect_external"
        expect(response).to redirect_to("https://example.com/callback", external: true)
      end

      it "matches URL with regex" do
        get "/redirect_external"
        expect(response).to redirect_to(%r{example\.com}, external: true)
      end

      it "does not match when external option is missing" do
        get "/redirect_external"
        expect(response).not_to redirect_to("https://example.com/callback")
      end
    end
  end
end
