# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Inertia::Frontend do
  around do |example|
    described_class.instance_variable_set(:@root, nil)
    described_class.instance_variable_set(:@dist, nil)
    described_class.instance_variable_set(:@version, nil)
    described_class.instance_variable_set(:@package_runner, nil)
    described_class.instance_variable_set(:@layout, nil)

    example.run

    described_class.instance_variable_set(:@root, nil)
    described_class.instance_variable_set(:@dist, nil)
    described_class.instance_variable_set(:@version, nil)
    described_class.instance_variable_set(:@package_runner, nil)
    described_class.instance_variable_set(:@layout, nil)
  end

  describe ".root" do
    it "returns the directory containing vite.config.js" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("frontend")
        frontend.mkpath
        frontend.join("vite.config.js").write("")

        allow(Rage).to receive(:root).and_return(root)

        expect(described_class.root).to eq(frontend)
      end
    end

    it "finds vite.config.ts in nested app directory" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("app/client")
        frontend.mkpath
        frontend.join("vite.config.ts").write("")

        allow(Rage).to receive(:root).and_return(root)

        expect(described_class.root).to eq(frontend)
      end
    end

    it "finds vite.config.mjs" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("client")
        frontend.mkpath
        frontend.join("vite.config.mjs").write("")

        allow(Rage).to receive(:root).and_return(root)

        expect(described_class.root).to eq(frontend)
      end
    end

    it "finds vite.config.mts" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("client")
        frontend.mkpath
        frontend.join("vite.config.mts").write("")

        allow(Rage).to receive(:root).and_return(root)

        expect(described_class.root).to eq(frontend)
      end
    end

    it "raises when no Vite config is found" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        allow(Rage).to receive(:root).and_return(root)

        expect { described_class.root }.to raise_error(RuntimeError, /Vite config not found/)
      end
    end

    it "memoizes the result" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("frontend")
        frontend.mkpath
        frontend.join("vite.config.js").write("")

        allow(Rage).to receive(:root).and_return(root)

        result1 = described_class.root
        result2 = described_class.root

        expect(result1).to equal(result2)
      end
    end

    context "with custom config" do
      before do
        allow(Inertia.config).to receive(:frontend_path).and_return(:custom_frontend_path)
      end

      it "returns configured root path" do
        expect(described_class.root).to eq(:custom_frontend_path)
      end
    end
  end

  describe ".dist" do
    let(:root) { double }

    before do
      allow(described_class).to receive(:root).and_return(root)
    end

    it "returns the default build directory" do
      expect(root).to receive(:join).with("dist").and_return(:default_build_path)
      expect(described_class.dist).to eq(:default_build_path)
    end

    context "with custom config" do
      before do
        allow(Inertia.config).to receive(:build_path).and_return(:custom_build_path)
      end

      it "returns configured root path" do
        expect(described_class.dist).to eq(:custom_build_path)
      end
    end
  end

  describe ".version" do
    it "returns MD5 hash of the Vite manifest" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("frontend")
        frontend.mkpath
        frontend.join("vite.config.js").write("")

        manifest_dir = frontend.join("dist/.vite")
        manifest_dir.mkpath
        manifest = manifest_dir.join("manifest.json")
        manifest.write('{"main.js": "main-abc123.js"}')

        allow(Rage).to receive(:root).and_return(root)

        expected_hash = Digest::MD5.file(manifest.to_s).hexdigest
        expect(described_class.version).to eq(expected_hash)
      end
    end

    it "falls back to index.html when manifest is missing" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("frontend")
        frontend.mkpath
        frontend.join("vite.config.js").write("")

        dist = frontend.join("dist")
        dist.mkpath
        index = dist.join("index.html")
        index.write("<html></html>")

        allow(Rage).to receive(:root).and_return(root)

        expected_hash = Digest::MD5.file(index.to_s).hexdigest
        expect(described_class.version).to eq(expected_hash)
      end
    end

    it "returns nil when no manifest or index.html exists" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("frontend")
        frontend.mkpath
        frontend.join("vite.config.js").write("")

        allow(Rage).to receive(:root).and_return(root)

        expect(described_class.version).to be_nil
      end
    end

    it "memoizes the result" do
      Dir.mktmpdir do |dir|
        root = Pathname.new(dir)
        frontend = root.join("frontend")
        frontend.mkpath
        frontend.join("vite.config.js").write("")

        dist = frontend.join("dist")
        dist.mkpath
        dist.join("index.html").write("<html></html>")

        allow(Rage).to receive(:root).and_return(root)

        result1 = described_class.version
        result2 = described_class.version

        expect(result1).to equal(result2)
      end
    end
  end

  describe ".package_runner" do
    def setup_frontend_with_lockfile(root, lockfile)
      frontend = root.join("frontend")
      frontend.mkpath
      frontend.join("vite.config.js").write("")
      frontend.join(lockfile).write("") if lockfile
      allow(Rage).to receive(:root).and_return(root)
    end

    it "returns 'npx' for npm (package-lock.json)" do
      Dir.mktmpdir do |dir|
        setup_frontend_with_lockfile(Pathname.new(dir), "package-lock.json")
        expect(described_class.package_runner).to eq("npx")
      end
    end

    it "returns 'pnpm exec' for pnpm (pnpm-lock.yaml)" do
      Dir.mktmpdir do |dir|
        setup_frontend_with_lockfile(Pathname.new(dir), "pnpm-lock.yaml")
        expect(described_class.package_runner).to eq("pnpm exec")
      end
    end

    it "returns 'bun x --bun' for bun (bun.lockb)" do
      Dir.mktmpdir do |dir|
        setup_frontend_with_lockfile(Pathname.new(dir), "bun.lockb")
        expect(described_class.package_runner).to eq("bun x --bun")
      end
    end

    it "returns 'bun x --bun' for bun (bun.lock)" do
      Dir.mktmpdir do |dir|
        setup_frontend_with_lockfile(Pathname.new(dir), "bun.lock")
        expect(described_class.package_runner).to eq("bun x --bun")
      end
    end

    it "returns 'yarn' for yarn (yarn.lock)" do
      Dir.mktmpdir do |dir|
        setup_frontend_with_lockfile(Pathname.new(dir), "yarn.lock")
        expect(described_class.package_runner).to eq("yarn")
      end
    end

    it "returns 'deno x' for deno (deno.lock)" do
      Dir.mktmpdir do |dir|
        setup_frontend_with_lockfile(Pathname.new(dir), "deno.lock")
        expect(described_class.package_runner).to eq("deno x")
      end
    end

    it "raises when no lock file is found" do
      Dir.mktmpdir do |dir|
        setup_frontend_with_lockfile(Pathname.new(dir), nil)
        expect { described_class.package_runner }.to raise_error(RuntimeError, /No supported package manager detected/)
      end
    end

    it "memoizes the result" do
      Dir.mktmpdir do |dir|
        setup_frontend_with_lockfile(Pathname.new(dir), "package-lock.json")

        result1 = described_class.package_runner
        result2 = described_class.package_runner

        expect(result1).to equal(result2)
      end
    end
  end

  describe ".render_layout" do
    let(:page_data) { { component: "Home", props: { user: "Jonathan" } } }

    context "in development" do
      before do
        allow(Rage).to receive(:env).and_return(double(development?: true))
      end

      it "fetches layout from Vite dev server" do
        html = '<html><body><div id="app"></div></body></html>'.dup
        allow(Net::HTTP).to receive(:get).with(URI("http://localhost:5173")).and_return(html)

        result = described_class.render_layout(page_data)

        expect(result).to include('<script data-page="app" type="application/json">')
        expect(result).to include('"component":"Home"')
        expect(result).to include('"user":"Jonathan"')
      end

      it "rewrites src attributes with relative paths" do
        html = '<html><head><script src="/src/main.ts"></script></head><body></body></html>'.dup
        allow(Net::HTTP).to receive(:get).and_return(html)

        result = described_class.render_layout(page_data)

        expect(result).to include('src="http://localhost:5173/src/main.ts"')
        expect(result).not_to include('src="/src/main.ts"')
      end

      it "rewrites href attributes with relative paths" do
        html = '<html><head><link href="/styles/app.css"></head><body></body></html>'.dup
        allow(Net::HTTP).to receive(:get).and_return(html)

        result = described_class.render_layout(page_data)

        expect(result).to include('href="http://localhost:5173/styles/app.css"')
      end

      it "rewrites ES module imports" do
        html = <<~HTML.dup
          <html><head>
          <script type="module">import { createApp } from "/node_modules/vue/dist/vue.esm.js"</script>
          </head><body></body></html>
        HTML
        allow(Net::HTTP).to receive(:get).and_return(html)

        result = described_class.render_layout(page_data)

        expect(result).to include('from "http://localhost:5173/node_modules/vue/dist/vue.esm.js"')
      end

      it "handles single-quoted attributes" do
        html = "<html><head><script src='/src/main.ts'></script></head><body></body></html>".dup
        allow(Net::HTTP).to receive(:get).and_return(html)

        result = described_class.render_layout(page_data)

        expect(result).to include('src="http://localhost:5173/src/main.ts"')
      end

      it "handles single-quoted imports" do
        html = <<~HTML.dup
          <html><head>
          <script type="module">import App from '/src/App.vue'</script>
          </head><body></body></html>
        HTML
        allow(Net::HTTP).to receive(:get).and_return(html)

        result = described_class.render_layout(page_data)

        expect(result).to include('from "http://localhost:5173/src/App.vue"')
      end

      it "does not rewrite absolute URLs" do
        html = '<html><head><script src="https://cdn.example.com/lib.js"></script></head><body></body></html>'.dup
        allow(Net::HTTP).to receive(:get).and_return(html)

        result = described_class.render_layout(page_data)

        expect(result).to include('src="https://cdn.example.com/lib.js"')
      end
    end

    context "in production" do
      before do
        allow(Rage).to receive(:env).and_return(double(development?: false))
      end

      it "reads layout from dist/index.html" do
        Dir.mktmpdir do |dir|
          root = Pathname.new(dir)
          frontend = root.join("frontend")
          frontend.mkpath
          frontend.join("vite.config.js").write("")

          dist = frontend.join("dist")
          dist.mkpath
          dist.join("index.html").write('<html><body><div id="app"></div></body></html>')

          allow(Rage).to receive(:root).and_return(root)

          result = described_class.render_layout(page_data)

          expect(result).to include('<script data-page="app" type="application/json">')
          expect(result).to include('"component":"Home"')
        end
      end

      it "raises when dist/index.html does not exist" do
        Dir.mktmpdir do |dir|
          root = Pathname.new(dir)
          frontend = root.join("frontend")
          frontend.mkpath
          frontend.join("vite.config.js").write("")

          allow(Rage).to receive(:root).and_return(root)

          expect { described_class.render_layout(page_data) }.to raise_error(RuntimeError, /Production layout not found/)
        end
      end

      it "caches the layout file content" do
        Dir.mktmpdir do |dir|
          root = Pathname.new(dir)
          frontend = root.join("frontend")
          frontend.mkpath
          frontend.join("vite.config.js").write("")

          dist = frontend.join("dist")
          dist.mkpath
          index = dist.join("index.html")
          index.write('<html><body></body></html>')

          allow(Rage).to receive(:root).and_return(root)

          described_class.render_layout(page_data)

          # Modify file after first read
          index.write('<html><body>MODIFIED</body></html>')

          result = described_class.render_layout(page_data)

          # Should still use cached content
          expect(result).not_to include("MODIFIED")
        end
      end

      it "does not rewrite URLs in static layout" do
        Dir.mktmpdir do |dir|
          root = Pathname.new(dir)
          frontend = root.join("frontend")
          frontend.mkpath
          frontend.join("vite.config.js").write("")

          dist = frontend.join("dist")
          dist.mkpath
          dist.join("index.html").write('<html><head><script src="/assets/main-abc123.js"></script></head><body></body></html>')

          allow(Rage).to receive(:root).and_return(root)

          result = described_class.render_layout(page_data)

          expect(result).to include('src="/assets/main-abc123.js"')
          expect(result).not_to include("localhost:5173")
        end
      end
    end
  end

  describe "page data injection" do
    before do
      allow(Rage).to receive(:env).and_return(double(development?: true))
    end

    it "injects page data script after opening body tag" do
      html = '<html><body><div id="app"></div></body></html>'.dup
      allow(Net::HTTP).to receive(:get).and_return(html)

      result = described_class.render_layout({ component: "Test" })

      expect(result).to match(/<body>\s*<script data-page="app"/)
    end

    it "serializes page data as JSON" do
      html = '<html><body></body></html>'.dup
      allow(Net::HTTP).to receive(:get).and_return(html)

      data = { component: "Users/Show", props: { user: { name: "Jane", age: 30 } }, url: "/users/1" }
      result = described_class.render_layout(data)

      expect(result).to include(data.to_json)
    end

    it "embeds data in a non-executable script tag" do
      html = '<html><body></body></html>'.dup
      allow(Net::HTTP).to receive(:get).and_return(html)

      data = { props: { message: "Hello <script>alert('Hello')</script>" } }
      result = described_class.render_layout(data)

      expect(result).to include('type="application/json"')
      expect(result).to include(data.to_json)
    end

    it "respects dev server configuration" do
      allow(Inertia.config).to receive(:dev_server).and_return(double(host: "testhost", port: 1234))
      expect(Net::HTTP).to receive(:get).with(URI("http://testhost:1234")).and_return(+"")

      described_class.render_layout({})
    end
  end
end
