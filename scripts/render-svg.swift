//
//  render-svg.swift
//  Perch
//
//  Created by Kaan Firat.
//
//  Usage: render-svg <image.svg> <width> <height> <pixel width> <output.png>
//
//  Draws the SVG at width × height points in WebKit, which renders its blur
//  filters and system fonts (CoreSVG doesn't), on a transparent background,
//  and writes it scaled to the given pixel width.
//

import Cocoa
import WebKit

let arguments = CommandLine.arguments
func usage() -> Never {
    FileHandle.standardError.write("usage: render-svg <image.svg> <width> <height> <pixel width> <output.png>\n".data(using: .utf8)!)
    exit(2)
}
if arguments.count != 6 { usage() }
let size = NSSize(width: Double(arguments[2]) ?? 0, height: Double(arguments[3]) ?? 0)
let pixelWidth = Int(arguments[4]) ?? 0
if size.width <= 0 || size.height <= 0 || pixelWidth <= 0 { usage() }
let svg = try String(contentsOfFile: arguments[1], encoding: .utf8)
let output = URL(fileURLWithPath: arguments[5])

final class Renderer: NSObject, WKNavigationDelegate {
    let web = WKWebView(frame: NSRect(origin: .zero, size: size))

    func start() {
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = self
        // Inline, so no file access is needed for the SVG.
        web.loadHTMLString("""
            <html><body style="margin:0;background:transparent">
            <div style="width:\(Int(size.width))px;height:\(Int(size.height))px">\(svg)</div>
            </body></html>
            """, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give filters a beat to paint before taking the picture.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let config = WKSnapshotConfiguration()
            config.rect = NSRect(origin: .zero, size: size)
            webView.takeSnapshot(with: config) { image, error in
                guard let image else {
                    FileHandle.standardError.write("snapshot failed: \(String(describing: error))\n".data(using: .utf8)!)
                    exit(1)
                }
                do {
                    try self.png(from: image).write(to: output)
                    exit(0)
                } catch {
                    FileHandle.standardError.write("\(error)\n".data(using: .utf8)!)
                    exit(1)
                }
            }
        }
    }

    func png(from image: NSImage) throws -> Data {
        let pixelHeight = Int((Double(pixelWidth) * size.height / size.width).rounded())
        guard let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "render-svg", code: 1)
        }
        context.interpolationQuality = .high
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let cgImage = context.makeImage(),
              let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            throw NSError(domain: "render-svg", code: 2)
        }
        return data
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let renderer = Renderer()
renderer.start()
app.run()
