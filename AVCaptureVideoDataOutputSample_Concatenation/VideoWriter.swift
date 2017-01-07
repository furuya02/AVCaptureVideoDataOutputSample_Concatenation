//
//  VideoWriter.swift
//  AVCaptureVideoDataOutputSample_Concatenation
//
//  Created by hirauchi.shinichi on 2017/01/06.
//  Copyright © 2017年 SAPPOROWORKS. All rights reserved.
//

import UIKit
import AVFoundation


protocol VideoWriterDelegate {
    // 録画時間の更新
    func changeRecordingTime(s: Int64)
    // 録画終了
    func finishRecording(fileUrl: URL)
}

class VideoWriter : NSObject {
    
    var delegate: VideoWriterDelegate?
    
    fileprivate var writer: AVAssetWriter!
    fileprivate var videoInput: AVAssetWriterInput!
    fileprivate var audioInput: AVAssetWriterInput!
    
    fileprivate var lastTime: CMTime! // 最後に保存したデータのPTS
    fileprivate var offsetTime = kCMTimeZero // オフセットPTS(開始を0とする)

    fileprivate var recordingTime:Int64 = 0 // 録画時間
    
    fileprivate enum Status {
        case Start // 初期化時
        case Write // 書き込み中
        case Pause // 一時停止
        case Restart // 一時停止からの復帰
        case End // データ保存完了
    }
    
    fileprivate var status = Status.Start
    
    init(height:Int, width:Int, channels:Int, samples:Float64, recordingTime:Int64){
        
        self.recordingTime = recordingTime
        
        // データ保存のパスを生成
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0] as String
        let filePath : String? = "\(documentsDirectory)/temp.mov"
        if FileManager.default.fileExists(atPath: filePath!) {
            try? FileManager.default.removeItem(atPath: filePath!)
        }

        // AVAssetWriter生成
        writer = try? AVAssetWriter(outputURL: URL(fileURLWithPath: filePath!), fileType: AVFileTypeQuickTimeMovie)
        
        // Video入力
        let videoOutputSettings: Dictionary<String, AnyObject> = [
            AVVideoCodecKey : AVVideoCodecH264 as AnyObject,
            AVVideoWidthKey : width as AnyObject,
            AVVideoHeightKey : height as AnyObject
        ];
        videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings)
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)
        
        // Audio入力
        let audioOutputSettings: Dictionary<String, AnyObject> = [
            AVFormatIDKey : kAudioFormatMPEG4AAC as AnyObject,
            AVNumberOfChannelsKey : channels as AnyObject,
            AVSampleRateKey : samples as AnyObject,
            AVEncoderBitRateKey : 128000 as AnyObject
        ]
        audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
        audioInput.expectsMediaDataInRealTime = true
        writer.add(audioInput)
    }
    
    func RecodingTime() -> CMTime {
        return CMTimeSubtract(lastTime, offsetTime)
    }
    
    func write(sampleBuffer: CMSampleBuffer, isVideo: Bool){
        
        if status == .Start || status == .End || status == .Pause {
            return
        }

        // 一時停止から復帰した場合は、一時停止中の時間をoffsetTimeに追加する
        if status == .Restart {
            let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) // 今取得したデータの時間
            let spanTime = CMTimeSubtract(timeStamp, lastTime) // 最後に取得したデータとの差で一時停止中の時間を計算する
            offsetTime = CMTimeAdd(offsetTime, spanTime) // 一時停止中の時間をoffsetTimeに追加する
            status = .Write
        }
        
        if CMSampleBufferDataIsReady(sampleBuffer) {

            // 開始直後は音声データのみしか来ないので、最初の動画が来てから書き込みを開始する
            if isVideo && writer.status == .unknown {
                offsetTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) // 開始時間を0とするために、開始時間をoffSetに保存する
                writer?.startWriting()
                writer?.startSession(atSourceTime: kCMTimeZero) // 開始時間を0で初期化する
            }
            
            if writer.status == .writing {
                
                // PTSの調整（offSetTimeだけマイナスする）
                var copyBuffer : CMSampleBuffer?
                var count: CMItemCount = 1
                var info = CMSampleTimingInfo()
                CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, count, &info, &count)
                info.presentationTimeStamp = CMTimeSubtract(info.presentationTimeStamp, offsetTime)
                CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,sampleBuffer,1,&info,&copyBuffer)
                
                lastTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) // 最後のデータの時間を記録する
                if RecodingTime() > CMTimeMake(Int64(recordingTime), 1) {
                    self.writer.finishWriting(completionHandler: {
                        DispatchQueue.main.async {
                            self.delegate?.finishRecording(fileUrl: self.writer.outputURL) // 録画終了
                        }
                    })
                    status = .End
                    return
                }

                if isVideo {
                    if (videoInput?.isReadyForMoreMediaData)! {
                        videoInput?.append(copyBuffer!)
                    }
                }else{
                    if (audioInput?.isReadyForMoreMediaData)! {
                        audioInput?.append(copyBuffer!)
                    }
                }
                delegate?.changeRecordingTime(s: RecodingTime().value) // 録画時間の更新
            }
        }
    }
    
    func pause(){
        if status == .Write {
            status = .Pause
        }
    }
    
    func start(){
        if status == .Start {
            status = .Write
        } else if status == .Pause {
            status = .Restart // 一時停止中の時間をPauseTimeに追加するためのステータス
        }
    }
}

/*
 フレーム通りに動画データが入ってくると言う前提なら
 次のように開始時間を0にして、(counter,30)を追加していく方法もある
 writer?.startWriting()
 writer?.startSession(atSourceTime: kCMTimeZero)
 
 var info = CMSampleTimingInfo(duration: CMTimeMake(1,30), presentationTimeStamp: CMTimeMake(frameCounter,30), decodeTimeStamp: kCMTimeInvalid)
 var copyBuffer : CMSampleBuffer?
 CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,sampleBuffer,1,&info,&copyBuffer)
 
 writer endSessionAtSourceTime:CMTimeMake((int64_t)(frameCount - 1) * fps * durationForEachImage, fps)];
 */
