#if os(iOS)
import AVFoundation
import Speech
import UIKit
import CwlCatchException

/// Foreground-only PCM in RAM. No speech request exists until the answer tap.
@available(iOS 10.0, *)
final class SpeechAudioPrebuffer {
  private let engine = AVAudioEngine()
  private let lock = NSLock()
  private var ring: [AVAudioPCMBuffer] = []
  private var ringFrames = 0
  private var pending: [AVAudioPCMBuffer] = []
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var armed = false
  private var ended = false
  private var deadline: DispatchWorkItem?
  private var ready: ((Bool) -> Void)?
  private var observer: NSObjectProtocol?
  private var interruption: NSObjectProtocol?
  private var route: NSObjectProtocol?
  private var installed = false
  private var firstSample = true
  private var endAt: TimeInterval = .greatestFiniteMagnitude
  private var previous: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?

  var isRunning: Bool { engine.isRunning }
  var isArmed: Bool { lock.lock(); defer { lock.unlock() }; return armed }

  func resolveReadinessTimeout() {
    if ready != nil { close() }
  }

  func start(ready: @escaping (Bool) -> Void) throws {
    self.ready = ready
    let session = AVAudioSession.sharedInstance()
    previous = (session.category, session.mode, session.categoryOptions)
    try session.setCategory(.playAndRecord, mode: .default,
                            options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
    try session.setActive(true)
    if #available(iOS 13.0, *) {
      try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
    }
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0, format.channelCount <= 2 else {
      throw SpeechToTextError.runtimeError("Microphone format unavailable")
    }
    try catchExceptionAsError {
      input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
        self?.receive(buffer)
      }
    }
    installed = true
    observer = NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.close() }
    interruption = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification, object: session, queue: .main
    ) { [weak self] note in
      if (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue {
        self?.close()
      }
    }
    route = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
    ) { [weak self] note in
      let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
      if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ||
          reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue {
        self?.close()
      }
    }
    engine.prepare()
    try engine.start()
  }

  /// Preserve the last 300ms (including finger-down before the tap's finger-up).
  func begin() -> Bool {
    lock.lock()
    guard engine.isRunning, !armed else { lock.unlock(); return false }
    pending = ring
    ring.removeAll(); ringFrames = 0
    armed = true; ended = false
    endAt = ProcessInfo.processInfo.systemUptime + 3
    lock.unlock()
    let finish = DispatchWorkItem { [weak self] in self?.finish() }
    deadline = finish
    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: finish)
    return true
  }

  /// Prefix and live audio share the same lock, so no sample is lost or reordered.
  func attach(_ target: SFSpeechAudioBufferRecognitionRequest) throws {
    lock.lock(); defer { lock.unlock() }
    guard armed else { throw SpeechToTextError.runtimeError("Audio buffer not armed") }
    for buffer in pending { target.append(buffer) }
    pending.removeAll()
    request = target
    if ended { target.endAudio() }
  }

  func finish() {
    deadline?.cancel(); deadline = nil
    lock.lock()
    if !ended { ended = true; request?.endAudio() }
    lock.unlock()
    try? catchExceptionAsError { engine.stop() }
  }

  func close() {
    finish()
    if installed {
      try? catchExceptionAsError { engine.inputNode.removeTap(onBus: 0) }
      installed = false
    }
    lock.lock()
    request = nil; armed = false
    pending.removeAll(); ring.removeAll(); ringFrames = 0
    lock.unlock()
    if let observer { NotificationCenter.default.removeObserver(observer) }
    if let interruption { NotificationCenter.default.removeObserver(interruption) }
    if let route { NotificationCenter.default.removeObserver(route) }
    observer = nil; interruption = nil; route = nil
    if let previous {
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(previous.0, mode: previous.1, options: previous.2)
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      self.previous = nil
    }
    let completion = ready; ready = nil
    completion?(false)
  }

  private func receive(_ input: AVAudioPCMBuffer) {
    guard input.frameLength > 0 else { return }
    lock.lock()
    if armed && ProcessInfo.processInfo.systemUptime >= endAt && !ended {
      ended = true
      request?.endAudio()
      DispatchQueue.main.async { [weak self] in self?.finish() }
    }
    if ended { lock.unlock(); return }
    if let request {
      request.append(input)
    } else if let copy = AVAudioPCMBuffer(pcmFormat: input.format, frameCapacity: input.frameLength) {
      copy.frameLength = input.frameLength
      let source = UnsafeMutableAudioBufferListPointer(input.mutableAudioBufferList)
      let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
      for i in 0..<source.count {
        if let src = source[i].mData, let dst = destination[i].mData {
          memcpy(dst, src, Int(min(source[i].mDataByteSize, destination[i].mDataByteSize)))
        }
      }
      if armed {
        // Startup is bounded to the same 3s capture window, never an unbounded queue.
        pending.append(copy)
      } else {
        ring.append(copy); ringFrames += Int(copy.frameLength)
        let limit = Int(input.format.sampleRate * 0.3)
        while ringFrames > limit && !ring.isEmpty {
          ringFrames -= Int(ring.removeFirst().frameLength)
        }
      }
    }
    let announce = firstSample
    firstSample = false
    lock.unlock()
    // Flutter result completion stays on the main thread; only the first sample qualifies.
    guard announce else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, self.engine.isRunning, let completion = self.ready else { return }
      self.ready = nil
      completion(true)
    }
  }
}
#endif
