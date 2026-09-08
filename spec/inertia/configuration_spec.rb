# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Inertia::Configuration do
  subject { described_class.new }

  around do |example|
    original_config = Inertia.instance_variable_get(:@config)
    Inertia.instance_variable_set(:@config, nil)

    example.run

    Inertia.instance_variable_set(:@config, original_config)
  end

  describe "#frontend_path=" do
    it "sets the frontend path relative to the application root" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        subject.frontend_path = "client"

        expect(subject.frontend_path).to eq(root.join("client"))
      end
    end

    it "handles nested paths" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        subject.frontend_path = "app/frontend"

        expect(subject.frontend_path).to eq(root.join("app/frontend"))
      end
    end
  end

  describe "#build_path=" do
    it "sets the build path relative to the application root" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        subject.build_path = "public/app"

        expect(subject.build_path).to eq(root.join("public/app"))
      end
    end

    it "handles nested paths" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        subject.build_path = "public/assets/frontend"

        expect(subject.build_path).to eq(root.join("public/assets/frontend"))
      end
    end

    it "raises when building directly into public/" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        expect { subject.build_path = "public" }.to raise_error(
          ArgumentError,
          /build_path cannot be set to public\/; use a nested directory instead/
        )
      end
    end
  end

  describe "#ssr" do
    it "returns an Ssr configuration object" do
      expect(subject.ssr).to be_a(Inertia::Configuration::Ssr)
    end

    it "returns the same object on subsequent calls" do
      expect(subject.ssr).to equal(subject.ssr)
    end
  end
end

RSpec.describe Inertia::Configuration::Ssr do
  subject { described_class.new }

  around do |example|
    original_config = Inertia.instance_variable_get(:@config)
    Inertia.instance_variable_set(:@config, nil)

    example.run

    Inertia.instance_variable_set(:@config, original_config)
  end

  describe "#enabled" do
    it "defaults to nil" do
      expect(subject.enabled).to be_nil
    end

    it "can be set to true" do
      subject.enabled = true
      expect(subject.enabled).to be true
    end

    it "can be set to false" do
      subject.enabled = false
      expect(subject.enabled).to be false
    end
  end

  describe "#url" do
    it "defaults to localhost:13714" do
      expect(subject.url).to eq("http://localhost:13714")
    end

    it "can be changed" do
      subject.url = "http://ssr.example.com:3000"
      expect(subject.url).to eq("http://ssr.example.com:3000")
    end
  end

  describe "#build_path=" do
    it "sets the build path relative to the application root" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        subject.build_path = "dist/ssr"

        expect(subject.build_path).to eq(root.join("dist/ssr"))
      end
    end

    it "handles nested paths" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        subject.build_path = "public/assets/ssr"

        expect(subject.build_path).to eq(root.join("public/assets/ssr"))
      end
    end

    it "raises when building directly into public/" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        expect { subject.build_path = "public" }.to raise_error(
          ArgumentError,
          /ssr.build_path cannot be set to public\/; use a nested directory instead/
        )
      end
    end
  end

  describe "#local?" do
    it "returns true for default localhost URL" do
      expect(subject.local?).to be true
    end

    it "returns true for localhost" do
      subject.url = "http://localhost:3000"
      expect(subject.local?).to be true
    end

    it "returns true for localhost. (with trailing dot)" do
      subject.url = "http://localhost.:3000"
      expect(subject.local?).to be true
    end

    it "returns true for 0.0.0.0" do
      subject.url = "http://0.0.0.0:13714"
      expect(subject.local?).to be true
    end

    it "returns true for ::1 (IPv6 loopback)" do
      subject.url = "http://[::1]:13714"
      expect(subject.local?).to be true
    end

    it "returns true for 127.0.0.1" do
      subject.url = "http://127.0.0.1:13714"
      expect(subject.local?).to be true
    end

    it "returns true for any 127.x.x.x address" do
      subject.url = "http://127.255.255.255:13714"
      expect(subject.local?).to be true
    end

    it "is case insensitive" do
      subject.url = "http://LOCALHOST:3000"
      expect(subject.local?).to be true
    end

    it "returns false for remote hosts" do
      subject.url = "http://ssr.example.com:3000"
      expect(subject.local?).to be false
    end

    it "returns false for IP addresses outside 127.x.x.x range" do
      subject.url = "http://192.168.1.1:3000"
      expect(subject.local?).to be false
    end
  end
end
