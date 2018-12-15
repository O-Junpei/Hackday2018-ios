import UIKit
import Alamofire
import SwiftyJSON
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    // MARK: Properties
    //localeのidentifierに言語を指定、。日本語はja-JP,英語はen-US
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    //録音の開始、停止ボタン
    var recordButton : UIButton!
    
    //文字音声認識された
    var voiceStr : String! = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let width: CGFloat = view.frame.width
        let height: CGFloat = view.frame.height
        
        view.backgroundColor = UIColor(named: "backgroundColor")

        let plantImageView = UIImageView()
        plantImageView.image = UIImage(named: "plant_sansevieria")
        plantImageView.contentMode = .scaleAspectFit
        plantImageView.frame = CGRect(x: width * 0.1, y: height * 0.2, width: width * 0.8, height: height * 0.6)
        view.addSubview(plantImageView)
        
        let talkButton = UIButton()
        talkButton.frame = CGRect(x: width * 0.15, y: height * 0.8, width: width * 0.7, height: height * 0.1)
        talkButton.backgroundColor = UIColor(named: "buttonColor")
        talkButton.layer.masksToBounds = true
        talkButton.layer.cornerRadius = 20.0
        talkButton.setTitle("Talk", for: .normal)
        talkButton.titleLabel?.font = UIFont.systemFont(ofSize: 60)
        talkButton.setTitleColor(UIColor(named: "buttonTextColor"), for: .normal)
        talkButton.addTarget(self, action: #selector(recordButtonTapped(sender:)), for:.touchUpInside)
        view.addSubview(talkButton)
        
        //デリゲートの設定
        speechRecognizer.delegate = self as! SFSpeechRecognizerDelegate
        
        //ユーザーに音声認識の許可を求める
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    //ユーザが音声認識の許可を出した時
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    //ユーザが音声認識を拒否した時
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    //端末が音声認識に対応していない場合
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    //ユーザが音声認識をまだ認証していない時
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
    
    
    
    // MARK: 録音ボタンが押されたら呼ばれる
    @objc func recordButtonTapped(sender: UIButton) {
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
            
            //録音が停止した！
            print("録音停止")
            
            //入力された文字列の入った文字列を表示
            showStrAlert(str: self.voiceStr)
            
        } else {
            try! startRecording()
            recordButton.setTitle("Stop recording", for: [])
        }
    }
    
    //渡された文字列が入ったアラートを表示する
    func showStrAlert(str: String){
        
        // UIAlertControllerを作成する.
        let myAlert: UIAlertController = UIAlertController(title: "音声認識結果", message: str, preferredStyle: .alert)
        
        // OKのアクションを作成する.
        let myOkAction = UIAlertAction(title: "OK", style: .default) { action in
            print("Action OK!!")
        }
        
        // OKのActionを追加する.
        myAlert.addAction(myOkAction)
        
        // UIAlertを発動する.
        present(myAlert, animated: true, completion: nil)
    }
    
    
    //録音を開始する
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        // try audioSession.setCategory(AVAudioSession.Category.record)
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [])

        
        try audioSession.setMode(AVAudioSession.Mode.measurement)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                
                //音声認識の区切りの良いところで実行される。
                self.voiceStr = result.bestTranscription.formattedString
                print(result.bestTranscription.formattedString)
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
    }
    
    // MARK: SFSpeechRecognizerDelegate
    //speechRecognizerが使用可能かどうかでボタンのisEnabledを変更する
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
            
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
}

