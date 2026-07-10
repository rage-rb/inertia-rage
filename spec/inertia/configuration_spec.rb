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
end
