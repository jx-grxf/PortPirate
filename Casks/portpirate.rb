cask "portpirate" do
  version "0.2.2"
  sha256 "REPLACE_WITH_DMG_SHA256_AT_RELEASE"

  url "https://github.com/jx-grxf/PortPirate/releases/download/v#{version}/PortPirate-#{version}.dmg",
      verified: "github.com/jx-grxf/PortPirate/"
  name "PortPirate"
  desc "Menu-bar utility that surfaces local dev ports and the AI agent that started them"
  homepage "https://github.com/jx-grxf/PortPirate"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "PortPirate.app"

  zap trash: [
    "~/Library/Application Support/PortPirate",
    "~/Library/Caches/at.johannesgrof.PortPirate",
    "~/Library/Preferences/at.johannesgrof.PortPirate.plist",
    "~/Library/Saved Application State/at.johannesgrof.PortPirate.savedState",
  ]
end
