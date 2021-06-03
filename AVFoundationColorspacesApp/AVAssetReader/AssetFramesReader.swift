import AVFoundation
import RxSwift

class AssetFramesReader {
  /// Describes a frame within a track.
  struct TimedCVPixelBuffer {
    /// The timestamp at which the frame appears.
    var time: CMTime

    /// `preferredTransform` of the track from which the frame was extracted.
    var preferredTransform: CGAffineTransform

    /// Contains the data of the frame.
    var buffer: CVPixelBuffer
  }

  /// The asset from which the data is read.
  var asset: AVAsset { assetReader.asset }

  /// Underlying asset reader.
  private let assetReader: AVAssetReader

  /// Chooses the needed tracks and time range given all the asset tracks.
  private let selectTracks: ([AVAssetTrack]) -> ([AVAssetTrack], CMTimeRange)

  /// Defines the tracks to read from and the reading options for each track.
  private var trackOutputs: [AVAssetReaderTrackOutput]!

  /// Ensures `cancel`, `getTimesOfFramesAfterTimeRangeEnd` and `readNextFrames` can't be run
  /// concurrently.
  private let readingFramesLock = NSLock()

  /// `true` iff reader setup was done.
  private var readerSetupDone = false

  /// Stores subscriptions disposables.
  private let disposeBag = DisposeBag()

  /// Time range of the tracks that should be read.
  private var targetTimeRange: CMTimeRange!

  /// Indicates whether the time of the first frame after the end of the time range should be
  /// saved.
  private let shouldSaveFramesTimesAfterTimeRangeEnd: Bool

  /// After reading is done, if `shouldSaveFramesTimesAfterTimeRangeEnd` is `true`
  /// this property will contain a dictionary mapping track id to the media time of the next
  /// frame after the last read frame (or the duration of the track if this is the last frame).
  /// otherwise this dictionary will be empty.
  private var timesOfFramesAfterTimeRangeEnd: [CMPersistentTrackID: CMTime] = [:]

  /// `true` iff reading of the time range is finished.
  var readingFinished = false

  /// `true` iff the reader read frames out of the time range.
  private var readOutOfRange = false

  /// Initializes with `asset` to read frames from and `selectTracks` to choose the needed tracks
  /// and time range for reading.
  /// If `shouldSaveFramesTimesAfterTimeRangeEnds == true` the reader will save the times of the
  /// first frames in each track after the end of the selected time range.
  init(asset: AVAsset, shouldSaveFramesTimesAfterTimeRangeEnd: Bool = false,
       selectTracks: @escaping ([AVAssetTrack]) -> ([AVAssetTrack], CMTimeRange)) {
    self.assetReader = try! AVAssetReader(asset: asset)
    self.shouldSaveFramesTimesAfterTimeRangeEnd = shouldSaveFramesTimesAfterTimeRangeEnd
    self.selectTracks = selectTracks
  }

  /// Returns the next frames from all selected tracks. Returns `nil` when there is no frames left
  /// in the time range defined by `selectTracks`.
  func readNextFrames() -> [CMPersistentTrackID: TimedCVPixelBuffer]? {
    readingFramesLock.lock()
    defer { readingFramesLock.unlock() }

    if !readerSetupDone {
      setupReader()
      readerSetupDone = true
    }

    var timedBuffers: [CMPersistentTrackID: TimedCVPixelBuffer] = [:]
    for trackOutput in trackOutputs {
      if let nextFrame = readNextFrame(inTrackOutput: trackOutput) {
        timedBuffers[trackOutput.track.trackID] = nextFrame
      }
    }

    cancelReadingIfNeeded()

    if readingFinished {
      precondition(assetReader.status == .completed || assetReader.status == .cancelled,
                   "Reader finished without completing or being cancelled. " +
                    "Status: \(assetReader.status.rawValue), " +
                    "Error: \(String(describing: assetReader.error))")
      return nil
    } else {
      return timedBuffers
    }
  }

  private func setupReader() {
    let setupDoneDispatchGroup = DispatchGroup()
    setupDoneDispatchGroup.enter()

    let keys = [#keyPath(AVAsset.isReadable), #keyPath(AVAsset.tracks)]
    asset.rx.loadValuesWithKeys(keys)
      .subscribe(onCompleted: { [weak self] in
        guard let self = self else { return }

        let (selectedTracks, targetTimeRange) =
          self.selectTracks(self.asset.tracks(withMediaType: .video))
        precondition(!selectedTracks.isEmpty, "No tracks were selected")

        let videoColorProperties = [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                                    //                                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_601_4
        ]

        let outputSettings: [String: Any] = [
          kCVPixelBufferPixelFormatTypeKey as String:
            [
              kCVPixelFormatType_32BGRA as NSValue,
              //              kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange as NSValue,
              //              kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as NSValue
            ],
          kCVPixelBufferIOSurfacePropertiesKey as String: [:],
          AVVideoColorPropertiesKey: videoColorProperties
        ]
        self.targetTimeRange = targetTimeRange
        self.assetReader.timeRange = self.shouldSaveFramesTimesAfterTimeRangeEnd ?
          .init(start: targetTimeRange.start, end: self.asset.duration) : targetTimeRange

        self.trackOutputs = selectedTracks.map {
          AVAssetReaderTrackOutput(track: $0, outputSettings: outputSettings)
        }

        for trackOutput in self.trackOutputs {
          self.assetReader.add(trackOutput)
        }

        if !self.assetReader.startReading() {
          //          let selectedTracksInfo = selectedTracks.map {
          //            return "(trackID: \($0.trackID), size: \($0.ftv_transformedSize()), " +
          //              "subTypeFormat: \($0.ftv_subTypeMediaFormatDescription()))"
          //          }
          //          .joined(separator: ", ")
          //
          //          fatalError("Failed to read asset. " +
          //                     "Error: \(String(describing: self.assetReader.error)), " +
          //                     "selected tracks: \(selectedTracksInfo)")
          fatalError()
        }

        setupDoneDispatchGroup.leave()
      }, onError: { error in
        setupDoneDispatchGroup.leave()
        fatalError("Loading values for asset (\(self.asset)) failed: \(error)")
      })
      .disposed(by: disposeBag)

    setupDoneDispatchGroup.wait()
  }

  private func readNextFrame(inTrackOutput trackOutput: AVAssetReaderTrackOutput)
  -> TimedCVPixelBuffer? {
    // .copyNextSampleBuffer() ignores YCbCr properties.
    // changes CVImageBufferYCbCrMatrix = "ITU_R_601_4"


    guard let sampleBuffer = trackOutput.copyNextSampleBuffer() else {
      if shouldSaveFramesTimesAfterTimeRangeEnd {
        timesOfFramesAfterTimeRangeEnd[trackOutput.track.trackID] = asset.duration
      }
      readingFinished = true
      return nil
    }

    let presentationTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)

    if presentationTime >= targetTimeRange.end {
      precondition(shouldSaveFramesTimesAfterTimeRangeEnd,
                   "Read frame out of time range when not supposed to")
      timesOfFramesAfterTimeRangeEnd[trackOutput.track.trackID] = presentationTime
      readOutOfRange = true
      readingFinished = true
      return nil
    }

    precondition(!readingFinished && !readOutOfRange,
                 "Reading finished in some tracks but not the others")

    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      fatalError("Couldn't get CVPixelBuffer from \(sampleBuffer)")
    }

    //    CVBufferSetAttachment(imageBuffer,
    //                          kCVImageBufferColorPrimariesKey,
    //                          kCVImageBufferColorPrimaries_ITU_R_709_2,
    //                          .shouldPropagate)
    //    CVBufferSetAttachment(imageBuffer,
    //                          kCVImageBufferTransferFunctionKey,
    //                          kCVImageBufferTransferFunction_ITU_R_709_2,
    //                          .shouldPropagate)
    //    CVBufferSetAttachment(imageBuffer,
    //                          kCVImageBufferYCbCrMatrixKey,
    //                          kCVImageBufferYCbCrMatrix_ITU_R_709_2,
    //                          .shouldPropagate)
    //    writerAdaptor.append(pixelBuffer, withPresentationTime: PTS)


    let preferredTransform = trackOutput.track.preferredTransform
    print("sampleNuffer", sampleBuffer)
    print("imageNuffer", imageBuffer)
    return TimedCVPixelBuffer(
      time: presentationTime, preferredTransform: preferredTransform, buffer: imageBuffer
    )
  }

  private func cancelReadingIfNeeded() {
    if readOutOfRange && assetReader.status == .reading {
      assetReader.cancelReading()
    }
  }

  /// Cancels the reading process. Once called, the reader is no longer valid. And a new one should
  /// be created if one wishes to restart the reading process.
  func cancel() {
    readingFramesLock.lock()
    defer { readingFramesLock.unlock() }
    return assetReader.cancelReading()
  }

  /// If `shouldSaveFramesTimesAfterTimeRangeEnds` is `true`, and reading has finished, this method
  /// will return a dictionary mapping track ids to the time of the first frame after the
  /// end of the selected time range (or the duration of the asset if no such frame exists),
  /// otherwise the method will fail.
  func getTimesOfFramesAfterTimeRangeEnd() -> [CMPersistentTrackID: CMTime] {
    precondition(shouldSaveFramesTimesAfterTimeRangeEnd,
                 "Cannot get frame times from a reader that was not initialized to save them")

    readingFramesLock.lock()
    defer { readingFramesLock.unlock() }

    precondition(readingFinished, "Cannot get frame times before reading is finished")
    precondition(!timesOfFramesAfterTimeRangeEnd.isEmpty, "Next frame time not saved when it " +
                  "should.")

    return timesOfFramesAfterTimeRangeEnd
  }
}

extension AVAsset {
  /// Dictionary holding keys of loadable values in an asset. For each key this dictionary holds
  /// the status of the loading and an error if it exists.
  typealias RxValueStatuses = [String: (AVKeyValueStatus, Error?)]

  /// Thrown when an error has occurred during the loading process.
  struct RxValueLoadingError: Error {
    /// Describes the statuses of the different values.
    var valueStatuses: RxValueStatuses
  }
}

extension Reactive where Base: AVAsset {
  /// Loads values corresponding to `keys`. Completes without a value if the loading is successful.
  /// Otherwise, throws an error of type `AVAsset.RxValueStatuses` specifying why the loading
  /// failed.
  func loadValuesWithKeys(_ keys: [String]) -> Completable {
    return Completable.create { [weak base = self.base] completableObserver in
      guard let base = base else {
        completableObserver(.completed)
        return Disposables.create()
      }
      base.loadValuesAsynchronously(forKeys: keys) {
        var statuses: AVAsset.RxValueStatuses = [:]
        var allLoaded = true
        for key in keys {
          var error: NSError?
          let valueStatus = base.statusOfValue(forKey: key, error: &error)
          statuses[key] = (valueStatus, error)
          if valueStatus != .loaded {
            allLoaded = false
          }
        }
        if allLoaded {
          completableObserver(.completed)
        } else {
          completableObserver(.error(AVAsset.RxValueLoadingError(valueStatuses: statuses)))
        }
      }
      return Disposables.create()
    }
  }
}
