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
    @StateObject private var events = FixtureEvents()
    @State private var clicks = 0
    @State private var last = "None"
    @State private var text = ""
    @State private var toggle = false
    @State private var web = false
    @State private var tabSidebar = false
    @State private var hideTarget = false
    @State private var offset = CGPoint.zero
    @State private var secondWindow: NSWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("OpenRow Fixture").font(.title2.weight(.semibold))
                Spacer()
                Toggle("Tab sidebar", isOn: $tabSidebar).toggleStyle(.switch)
                    .accessibilityIdentifier("fixture.tabSidebarToggle")
                Toggle("Web fixture", isOn: $web).toggleStyle(.switch)
                    .accessibilityIdentifier("fixture.webToggle")
                Button("Reset") { clicks = 0; last = "None"; text = ""; hideTarget = false }
            }
            HStack(spacing: 24) {
                Text("Clicks: \(clicks)").accessibilityIdentifier("fixture.clickCount")
                Text("Last control: \(last)").accessibilityIdentifier("fixture.lastControl")
                Text("Scroll: x \(Int(offset.x)), y \(Int(offset.y))").monospacedDigit().accessibilityIdentifier("fixture.scrollPosition")
            }
            Text(events.lastScroll).font(.caption.monospaced())
            TextField("Ordinary typing passes through here", text: $text)
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("fixture.typing")
            HStack {
                Toggle("Enabled option", isOn: $toggle)
                Button("Disabled control") {}.disabled(true)
                Button(hideTarget ? "Show target" : "Hide target") { hideTarget.toggle() }
                if !hideTarget { Button("Single click target") { clicked("Single click target") } }
                Button("Open second window") {
                    let window = NSWindow(contentRect: NSRect(x: 70, y: 90, width: 260, height: 160),
                        styleMask: [.titled, .closable], backing: .buffered, defer: false)
                    window.title = "Second Fixture"
                    window.contentView = NSHostingView(rootView: Text("Second fixture window"))
                    window.isReleasedWhenClosed = false
                    secondWindow = window
                    window.makeKeyAndOrderFront(nil)
                }
            }
            if tabSidebar { TabSidebarFixture() }
            else if web { WebFixture() }
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

@MainActor private final class FixtureEvents: ObservableObject {
    @Published var lastScroll = "Wheel events: 0"
    private var count = 0
    private var monitor: Any?
    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.count += 1
                self.lastScroll = "Wheel events: \(self.count); point: \(event.locationInWindow); delta: \(event.scrollingDeltaX), \(event.scrollingDeltaY)"
            }
            return event
        }
    }
}

private struct WebFixture: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.loadHTMLString("""
        <!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
        <style>:root{color-scheme:light dark}body{font:15px system-ui;margin:18px}button{font:inherit;padding:8px;margin:5px}.regions{display:flex;gap:16px}.region{height:340px;overflow:auto;border:1px solid #888;padding:12px;flex:1}.wide{width:1000px}</style>
        <h2>WebKit controls and nested scrolling</h2><p id="count" role="status">Web clicks: 0</p>
        <p id="offsets">Web controls: x 0, y 0; Web reference: x 0, y 0</p>
        <div id="compound" role="link" aria-label="Compound row" tabindex="0" style="position:relative;height:44px;border:1px solid #888;margin-bottom:12px;display:flex;align-items:center;gap:8px;padding:0 12px">
        <span role="img" aria-label="Row artwork">&#9679;</span><span>Compound row label</span>
        <button id="accessory" style="position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);margin:0">Row accessory</button></div>
        <p id="row-count" role="status">Row clicks: 0; accessory clicks: 0</p>
        <div class="regions"><section class="region" aria-label="Web controls"><div class="wide" id="buttons"></div></section>
        <section class="region" aria-label="Nested reference"><div id="reference"></div></section></div>
        <script>let rows=0,accessories=0;const rowCount=()=>document.querySelector('#row-count').textContent=`Row clicks: ${rows}; accessory clicks: ${accessories}`;document.querySelector('#compound').onclick=()=>{rows++;rowCount()};document.querySelector('#accessory').onclick=e=>{e.stopPropagation();accessories++;rowCount()};let n=0;for(let i=1;i<=100;i++){const b=document.createElement('button');b.textContent='Web control '+i;b.onclick=()=>{document.querySelector('#count').textContent='Web clicks: '+(++n)};document.querySelector('#buttons').append(b)}for(let i=1;i<=60;i++){const p=document.createElement('p');p.textContent='Reference row '+i;document.querySelector('#reference').append(p)}
        const regions=[...document.querySelectorAll('.region')];for(const region of regions)region.addEventListener('scroll',()=>{document.querySelector('#offsets').textContent=`Web controls: x ${Math.round(regions[0].scrollLeft)}, y ${Math.round(regions[0].scrollTop)}; Web reference: x ${Math.round(regions[1].scrollLeft)}, y ${Math.round(regions[1].scrollTop)}`})</script></html>
        """, baseURL: nil)
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {}
}


/// A browser-style viewport: scrollable tab chrome without AXScrollArea or scrollbars.
private struct TabSidebarFixture: NSViewRepresentable {
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = TabSidebarScrollView()
        scroll.hasVerticalScroller = false
        scroll.drawsBackground = false
        scroll.setAccessibilityIdentifier("fixture.tabSidebar")
        let document = NSView(frame: CGRect(x: 0, y: 0, width: 850, height: 1800))
        document.setAccessibilityElement(true)
        document.setAccessibilityRole(.group)
        for index in 0..<40 {
            let button = NSButton(title: "Sidebar tab \(index + 1)", target: nil, action: nil)
            button.frame = CGRect(x: 16, y: 1748 - index * 44, width: 240, height: 36)
            document.addSubview(button)
        }
        scroll.documentView = document
        return scroll
    }
    func updateNSView(_ view: NSScrollView, context: Context) {}
}

private final class TabSidebarScrollView: NSScrollView {
    override func accessibilityRole() -> NSAccessibility.Role? { .tabGroup }
}
