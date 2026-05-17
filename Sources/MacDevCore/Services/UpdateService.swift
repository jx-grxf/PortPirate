import Foundation
import Sparkle

@MainActor
public final class UpdateService: NSObject {
  public static let stableAppcastURLString = "https://github.com/jx-grxf/MacDev/releases/latest/download/appcast.xml"
  public static let betaAppcastURLString = "https://github.com/jx-grxf/MacDev/releases/download/beta/appcast.xml"

  public static var isConfigured: Bool {
    guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
      return false
    }
    return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && key != "development-placeholder"
  }

  private var updaterController: SPUStandardUpdaterController!
  private var channelProvider: () -> UpdateChannel

  public init(channelProvider: @escaping () -> UpdateChannel) {
    self.channelProvider = channelProvider
    super.init()
    self.updaterController = SPUStandardUpdaterController(
      startingUpdater: false,
      updaterDelegate: self,
      userDriverDelegate: nil
    )
    if Self.isConfigured {
      self.updaterController.startUpdater()
    }
  }

  public var automaticallyChecksForUpdates: Bool {
    get { updaterController.updater.automaticallyChecksForUpdates }
    set { updaterController.updater.automaticallyChecksForUpdates = newValue }
  }

  public func checkForUpdates() {
    guard Self.isConfigured else { return }
    updaterController.checkForUpdates(nil)
  }
}

extension UpdateService: SPUUpdaterDelegate {
  public func allowedChannels(for updater: SPUUpdater) -> Set<String> {
    channelProvider().allowedChannels
  }

  public func feedURLString(for updater: SPUUpdater) -> String? {
    switch channelProvider() {
    case .stable:
      Self.stableAppcastURLString
    case .beta:
      Self.betaAppcastURLString
    }
  }
}
