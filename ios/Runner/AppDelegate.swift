import AVFoundation
import AudioToolbox
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UiSoundPlugin") {
      UiSoundPlugin.register(with: registrar)
    }
  }
}

/// UI 효과음 (`tapeletter/ui_sound`).
///
/// - 이어폰이 없으면 System Sound Services — 무음 스위치를 따르고, 앱의 AVAudioSession(녹음·재생)을
///   바꾸지 않아 다른 소리를 끊거나 줄이지 않는다.
/// - 이어폰(유선·블루투스·에어팟)으로 나가면 AVAudioPlayer — 무음 모드여도 들린다.
///   세션이 무음 스위치를 따르는 카테고리(ambient·soloAmbient)일 때만 효과음 동안
///   `.playback + .mixWithOthers`로 바꿨다가 끝나면 되돌린다. 녹음(playAndRecord)·테이프 재생(playback)
///   중이면 그 세션을 그대로 쓴다(카테고리를 건드리지 않는다).
/// - 출력 경로는 울릴 때마다 본다. 이어폰을 빼면(routeChange · oldDeviceUnavailable) 이어폰으로
///   울리던 효과음을 바로 멈춘다(스피커로 새지 않게).
final class UiSoundPlugin: NSObject, FlutterPlugin, AVAudioPlayerDelegate {
  private let registrar: FlutterPluginRegistrar
  private var sounds: [String: SystemSoundID] = [:]
  private var paths: [String: String] = [:]
  private var players: [String: AVAudioPlayer] = [:]

  /// 효과음 때문에 바꾼 세션 카테고리 (끝나면 되돌린다)
  private var borrowed: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(routeChanged(_:)),
      name: AVAudioSession.routeChangeNotification, object: nil)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "tapeletter/ui_sound", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(UiSoundPlugin(registrar: registrar), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "preload":
      // { 이름: Flutter 에셋 경로 }
      for (name, asset) in (call.arguments as? [String: String]) ?? [:] where sounds[name] == nil {
        let key = registrar.lookupKey(forAsset: asset)
        guard let path = Bundle.main.path(forResource: key, ofType: nil) else { continue }
        paths[name] = path
        load(name)
      }
      result(nil)
    case "play":
      if let name = call.arguments as? String {
        if UiSoundPlugin.headphonesConnected() {
          playThroughHeadphones(name)
        } else if let id = sounds[name] {
          AudioServicesPlaySystemSound(id)
        }
      }
      result(nil)
    case "stop":
      if let name = call.arguments as? String {
        // System Sound에는 멈춤이 없다. ID를 버리면 울리던 소리가 멈추고, 다음을 위해 다시 만든다.
        if let id = sounds[name] {
          AudioServicesDisposeSystemSoundID(id)
          sounds[name] = nil
          load(name)
        }
        if let p = players[name], p.isPlaying {
          p.stop()
          p.currentTime = 0
          giveBackIfIdle()
        }
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 지금 소리가 이어폰(유선·블루투스·에어팟·USB 헤드셋)으로 나가는지
  static func headphonesConnected() -> Bool {
    let ear: Set<AVAudioSession.Port> = [
      .headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .usbAudio,
    ]
    return AVAudioSession.sharedInstance().currentRoute.outputs.contains { ear.contains($0.portType) }
  }

  private func playThroughHeadphones(_ name: String) {
    guard let player = player(name) else {
      if let id = sounds[name] { AudioServicesPlaySystemSound(id) }
      return
    }
    borrowSessionIfSilenced()
    player.currentTime = 0
    player.play()
  }

  private func player(_ name: String) -> AVAudioPlayer? {
    if let p = players[name] { return p }
    guard let path = paths[name],
      let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
    else { return nil }
    p.delegate = self
    p.prepareToPlay()
    players[name] = p
    return p
  }

  /// 무음 스위치를 따르는 카테고리면 효과음 동안만 `.playback + .mixWithOthers`로.
  /// 다른 앱 소리·테이프 재생·녹음은 끊지 않는다(mixWithOthers, 녹음·재생 중이면 손대지 않음).
  private func borrowSessionIfSilenced() {
    let s = AVAudioSession.sharedInstance()
    guard borrowed == nil, s.category == .ambient || s.category == .soloAmbient else { return }
    let prev = (s.category, s.mode, s.categoryOptions)
    do {
      try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try s.setActive(true)
      borrowed = prev
    } catch {}
  }

  /// 빌린 세션을 되돌린다 — 효과음이 모두 끝났고, 그사이 다른 쪽(녹음·재생)이 바꾸지 않았을 때만.
  private func giveBackIfIdle() {
    guard let prev = borrowed, !players.values.contains(where: { $0.isPlaying }) else { return }
    borrowed = nil
    let s = AVAudioSession.sharedInstance()
    guard s.category == .playback, s.categoryOptions == [.mixWithOthers] else { return }
    // 먼저 (다른 소리와 섞이는 채로) 세션을 내려놓고 카테고리를 되돌린다 — 다른 앱 소리를 끊지 않게.
    // 앱의 다른 소리(테이프 재생)가 울리는 중이면 내려놓기가 실패하고, 카테고리만 원래대로 돌아간다.
    try? s.setActive(false, options: .notifyOthersOnDeactivation)
    try? s.setCategory(prev.0, mode: prev.1, options: prev.2)
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    giveBackIfIdle()
  }

  /// 이어폰을 빼면 이어폰으로 울리던 효과음을 바로 멈춘다.
  @objc private func routeChanged(_ note: Notification) {
    guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
      AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
    else { return }
    DispatchQueue.main.async {
      for p in self.players.values where p.isPlaying {
        p.stop()
        p.currentTime = 0
      }
      self.giveBackIfIdle()
    }
  }

  private func load(_ name: String) {
    guard let path = paths[name] else { return }
    var id: SystemSoundID = 0
    if AudioServicesCreateSystemSoundID(URL(fileURLWithPath: path) as CFURL, &id) == noErr {
      sounds[name] = id
    }
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    NotificationCenter.default.removeObserver(self)
    for id in sounds.values { AudioServicesDisposeSystemSoundID(id) }
    sounds.removeAll()
    for p in players.values { p.stop() }
    players.removeAll()
    giveBackIfIdle()
  }
}
