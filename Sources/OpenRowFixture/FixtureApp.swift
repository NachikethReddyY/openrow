import AppKit
import SwiftUI
import WebKit

@main struct FixtureApp: App {
    var body: some Scene {
        WindowGroup("OpenRow Fixture") { FixtureView() }
            .defaultSize(width: 1000, height: 720)
    }
}

struct FixtureView: View {
    @State private var clicks = 0
    @State private var last = "None"
    @State private var text = ""
    @State private var toggle = false
    @State private var web = false
    @State private var hideTarget = false
    @State private var offset = CGPoint.zero

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("OpenRow Fixture").font(.title2.weight(.semibold))
                Spacer()
                Toggle("Web fixture", isOn: $web).toggleStyle(.switch)
                Button("Reset") { clicks = 0; last = "None"; text = ""; hideTarget = false }
            }
            HStack(spacing: 24) {
                Text("Clicks: \(clicks)").accessibilityIdentifier("fixture.clickCount")
                Text("Last control: \(last)").accessibilityIdentifier("fixture.lastControl")
                Text("Scroll: x \(Int(offset.x)), y \(Int(offset.y))").monospacedDigit().accessibilityIdentifier("fixture.scrollPosition")
            }
            TextField("Ordinary typing passes through here", text: $text)
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("fixture.typing")
            HStack {
                Toggle("Enabled option", isOn: $toggle)
                Button("Disabled control") {}.disabled(true)
                Button(hideTarget ? "Show target" : "Hide target") { hideTarget.toggle() }
                if !hideTarget { Button("Single click target") { clicked("Single click target") } }
            }
            if web { WebFixture() }
            else {
                HStack(alignment: .top, spacing: 16) {
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(0..<30) { row in
                                HStack(spacing: 12) {
                                    ForEach(0..<10) { column in
                                        Button("Control \(row * 10 + column + 1)") { clicked("Control \(row * 10 + column + 1)") }
                                            .frame(width: 120)
                                    }
                                }
                            }
                        }.padding(12)
                    }
                    .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, new in offset = new }
                    .accessibilityLabel("Dense controls scroll region")
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Independent region").font(.headline)
                            ForEach(1..<61) { number in Text("Reference row \(number)") }
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 210)
                    .accessibilityLabel("Reference scroll region")
                }
            }
        }.padding(20)
    }

    private func clicked(_ title: String) { clicks += 1; last = title }
}

private struct WebFixture: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.loadHTMLString("""
        <!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
        <style>:root{color-scheme:light dark}body{font:15px system-ui;margin:18px}button{font:inherit;padding:8px;margin:5px}.regions{display:flex;gap:16px}.region{height:340px;overflow:auto;border:1px solid #888;padding:12px;flex:1}.wide{width:1000px}</style>
        <h2>WebKit controls and nested scrolling</h2><p id="count" role="status">Web clicks: 0</p>
        <div class="regions"><section class="region" aria-label="Web controls"><div class="wide" id="buttons"></div></section>
        <section class="region" aria-label="Nested reference"><div id="reference"></div></section></div>
        <script>let n=0;for(let i=1;i<=100;i++){const b=document.createElement('button');b.textContent='Web control '+i;b.onclick=()=>{document.querySelector('#count').textContent='Web clicks: '+(++n)};document.querySelector('#buttons').append(b)}for(let i=1;i<=60;i++){const p=document.createElement('p');p.textContent='Reference row '+i;document.querySelector('#reference').append(p)}</script></html>
        """, baseURL: nil)
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
