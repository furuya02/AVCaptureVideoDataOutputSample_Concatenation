//
//  ViewController.swift
//  AVCaptureVideoDataOutputSample_Concatenation
//
//  Created by hirauchi.shinichi on 2017/01/05.
//  Copyright © 2017年 SAPPOROWORKS. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController, VideoDelegate {

    @IBOutlet weak var recordingButton: UIButton!
    @IBOutlet weak var previewView: UIImageView!
    @IBOutlet weak var progressView: UIProgressView!

    fileprivate var recordingTime:Int64 = 6 // 録画時間(秒)

    var video: Video?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        // 録画中のボタンのイメージ
        recordingButton.setImage(UIImage(named: "buttonRecording"), for: .highlighted)
        // ブログレスビュー
        progressView.transform = CGAffineTransform(scaleX: 1, y: 5)
        progressView.trackTintColor = UIColor.black
        progressView.progressTintColor = UIColor.orange
        progressView.isHidden = true
        progressView.progress = 0
        
        video = Video()
        video?.delegate = self
        video?.setup(previewView: previewView, recordingTime: recordingTime)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func touchDownRecordingButton(_ sender: Any) {
        if (video?.start())! {
            progressView.isHidden = false
        }
    }
    
    @IBAction func touchUpRecordingButton(_ sender: Any) {
        video?.pause()
    }
    
    // 録画時間の更新
    func changeRecordingTime(s: Int64) {
        progressView.progress = Float(s) / (Float(recordingTime) * 1000000000)
    }
    
    // 録画終了
    func finishRecording(fileUrl: URL,completionHandler: @escaping ()->Swift.Void) {
        progressView.isHidden = true
        progressView.progress = 0
        print(fileUrl)
        
        let alertController = UIAlertController(title: "撮影を完了しました", message: "保存しますか？", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "はい", style: .default, handler:{
            (action: UIAlertAction!) -> Void in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileUrl)
            }) { completed, error in
                if completed {
                    print("Video is saved!")
                }
                if (error != nil) {
                    print("ERROR=\(error)")
                }
                completionHandler()
            }
        }))
        alertController.addAction(UIAlertAction(title: "いいえ", style: .cancel, handler:{
            (action: UIAlertAction!) -> Void in
            completionHandler()
        }))
        present(alertController, animated: true, completion: nil)

    }
        
}

