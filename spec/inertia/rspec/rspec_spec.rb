# frozen_string_literal: true

module RspecSpecHelpers
  class TestController < RageController::API
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
  end

  Rage.routes.draw do
    root to: "rspec_spec_helpers/test#index"
    get "/users/:id", to: "rspec_spec_helpers/test#show"
    get "/plain", to: "rspec_spec_helpers/test#plain"
    get "/json", to: "rspec_spec_helpers/test#json_response"
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
end
