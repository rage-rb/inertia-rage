# frozen_string_literal: true

require "spec_helper"

RSpec.describe Inertia::SSR::Server do
  subject { described_class.new }

  before do
    allow(subject).to receive(:puts)
  end

  describe "#perform" do
    it "logs a startup message" do
      ssr_dist = instance_double(Pathname)
      logger = double("Logger")
      allow(Inertia::Frontend).to receive(:ssr_dist).and_return(ssr_dist)
      allow(ssr_dist).to receive(:glob).with("*.{js,mjs}").and_return([])
      allow(Rage).to receive(:logger).and_return(logger)
      allow(logger).to receive(:fatal)

      expect(subject).to receive(:puts).with("INFO: Starting SSR server")

      subject.perform
    end

    context "when SSR bundle exists" do
      let(:frontend_root) { Pathname.new("/app/frontend") }
      let(:ssr_bundle) { Pathname.new("/app/frontend/dist/ssr/ssr.js") }

      before do
        allow(Inertia::Frontend).to receive(:root).and_return(frontend_root)
        allow(Inertia::Frontend).to receive(:runtime).and_return("node")
        allow(ssr_bundle).to receive(:exist?).and_return(true)
      end

      it "spawns the SSR server process using the detected runtime" do
        ssr_dist = instance_double(Pathname)
        allow(Inertia::Frontend).to receive(:ssr_dist).and_return(ssr_dist)
        allow(ssr_dist).to receive(:glob).with("*.{js,mjs}").and_return([ssr_bundle])

        expect(Process).to receive(:spawn).with(
          "node dist/ssr/ssr.js",
          chdir: frontend_root
        ).and_return(12345)
        expect(Process).to receive(:wait).with(12345)

        subject.perform
      end

      it "uses bun runtime when detected" do
        allow(Inertia::Frontend).to receive(:runtime).and_return("bun")

        ssr_dist = instance_double(Pathname)
        allow(Inertia::Frontend).to receive(:ssr_dist).and_return(ssr_dist)
        allow(ssr_dist).to receive(:glob).with("*.{js,mjs}").and_return([ssr_bundle])

        expect(Process).to receive(:spawn).with(
          "bun dist/ssr/ssr.js",
          chdir: frontend_root
        ).and_return(12345)
        expect(Process).to receive(:wait).with(12345)

        subject.perform
      end

      it "uses deno runtime when detected" do
        allow(Inertia::Frontend).to receive(:runtime).and_return("deno run --allow-net --allow-env")

        ssr_dist = instance_double(Pathname)
        allow(Inertia::Frontend).to receive(:ssr_dist).and_return(ssr_dist)
        allow(ssr_dist).to receive(:glob).with("*.{js,mjs}").and_return([ssr_bundle])

        expect(Process).to receive(:spawn).with(
          "deno run --allow-net --allow-env dist/ssr/ssr.js",
          chdir: frontend_root
        ).and_return(12345)
        expect(Process).to receive(:wait).with(12345)

        subject.perform
      end
    end

    context "when SSR bundle does not exist" do
      let(:logger) { double("Logger") }

      before do
        allow(Rage).to receive(:logger).and_return(logger)
      end

      it "logs a fatal error and returns Stop" do
        ssr_dist = instance_double(Pathname)
        allow(Inertia::Frontend).to receive(:ssr_dist).and_return(ssr_dist)
        allow(ssr_dist).to receive(:glob).with("*.{js,mjs}").and_return([])

        expect(logger).to receive(:fatal).with("Could not start SSR server - bundle not found")

        result = subject.perform
        expect(result).to eq(Rage::Daemon::Stop)
      end

      it "does not spawn any process" do
        ssr_dist = instance_double(Pathname)
        allow(Inertia::Frontend).to receive(:ssr_dist).and_return(ssr_dist)
        allow(ssr_dist).to receive(:glob).with("*.{js,mjs}").and_return([])
        allow(logger).to receive(:fatal)

        expect(Process).not_to receive(:spawn)

        subject.perform
      end

      it "handles bundle file that does not exist on disk" do
        ssr_dist = instance_double(Pathname)
        ssr_bundle = instance_double(Pathname)
        allow(Inertia::Frontend).to receive(:ssr_dist).and_return(ssr_dist)
        allow(ssr_dist).to receive(:glob).with("*.{js,mjs}").and_return([ssr_bundle])
        allow(ssr_bundle).to receive(:exist?).and_return(false)

        expect(logger).to receive(:fatal).with("Could not start SSR server - bundle not found")

        result = subject.perform
        expect(result).to eq(Rage::Daemon::Stop)
      end
    end
  end

  describe "#cleanup" do
    it "sends TERM signal to the SSR process" do
      subject.instance_variable_set(:@pid, 12345)

      expect(Process).to receive(:kill).with("TERM", 12345)

      subject.cleanup
    end

    it "handles already terminated process" do
      subject.instance_variable_set(:@pid, 12345)
      allow(Process).to receive(:kill).and_raise(Errno::ESRCH)

      expect { subject.cleanup }.not_to raise_error
    end

    it "does nothing when pid is not set" do
      expect(Process).not_to receive(:kill)

      subject.cleanup
    end
  end
end
