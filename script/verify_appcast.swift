#!/usr/bin/xcrun swift
import Foundation

func fail(_ message: String) -> Never {
  fputs("\(message)\n", stderr)
  exit(1)
}

let args = CommandLine.arguments
guard args.count == 4 else {
  fail("usage: verify_appcast.swift <appcast.xml> <expected-zip-url> <stable|beta>")
}

let appcastURL = URL(fileURLWithPath: args[1])
let expectedZipURL = args[2]
let expectedChannel = args[3]

guard expectedChannel == "stable" || expectedChannel == "beta" else {
  fail("expected channel must be stable or beta")
}

let document: XMLDocument
do {
  document = try XMLDocument(contentsOf: appcastURL, options: [])
} catch {
  fail("appcast.xml is not valid XML: \(error.localizedDescription)")
}

guard let root = document.rootElement(), root.name == "rss" else {
  fail("appcast.xml root element must be rss")
}

guard
  let channel = root.elements(forName: "channel").first,
  let item = channel.elements(forName: "item").first,
  let enclosure = item.elements(forName: "enclosure").first
else {
  fail("appcast.xml must contain rss/channel/item/enclosure")
}

func attribute(_ name: String, in element: XMLElement) -> String? {
  element.attribute(forName: name)?.stringValue
}

guard let enclosureURL = attribute("url", in: enclosure), !enclosureURL.isEmpty else {
  fail("Sparkle enclosure is missing url")
}

guard enclosureURL == expectedZipURL else {
  fail("Sparkle enclosure url mismatch. Expected \(expectedZipURL), got \(enclosureURL)")
}

guard enclosureURL.contains("/PortPirate-"), enclosureURL.hasSuffix(".zip") else {
  fail("Sparkle enclosure must point at a PortPirate zip asset")
}

let signature = attribute("sparkle:edSignature", in: enclosure)
  ?? attribute("edSignature", in: enclosure)
guard signature?.isEmpty == false else {
  fail("Sparkle enclosure is missing an EdDSA signature")
}

let version = attribute("sparkle:version", in: enclosure)
  ?? attribute("version", in: enclosure)
guard version?.isEmpty == false else {
  fail("Sparkle enclosure is missing a version")
}

let channelValue = attribute("sparkle:channel", in: enclosure)
  ?? attribute("channel", in: enclosure)
if expectedChannel == "stable" {
  guard channelValue == nil else {
    fail("Stable appcast must not include sparkle:channel")
  }
} else {
  guard channelValue == "beta" else {
    fail("Beta appcast must include sparkle:channel=\"beta\"")
  }
}

print("Sparkle appcast smoke test passed.")
