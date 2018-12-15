import UIKit
import Alamofire
import SwiftyJSON
import Speech
import AVFoundation

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    // MARK: Properties
    //localeのidentifierに言語を指定、。日本語はja-JP,英語はen-US
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    //録音の開始、停止ボタン
    //var recordButton : UIButton!
    
    //文字音声認識された
    var voiceStr : String! = ""
    var beforeStr = ""
    
    let talkButton = UIButton()
    
    // AVSpeechSynthesizerをクラス変数で保持しておく、インスタンス変数だと読み上げるまえに破棄されてしまう
    var speechSynthesizer : AVSpeechSynthesizer!
    
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
        speechRecognizer.delegate = self as SFSpeechRecognizerDelegate
        
        //ユーザーに音声認識の許可を求める
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    //ユーザが音声認識の許可を出した時
                    //self.recordButton.isEnabled = true
                    print("ok")
                    
                case .denied:
                    //ユーザが音声認識を拒否した時
                    self.talkButton.isEnabled = false
                    self.talkButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    //端末が音声認識に対応していない場合
                    self.talkButton.isEnabled = false
                    self.talkButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    //ユーザが音声認識をまだ認証していない時
                    self.talkButton.isEnabled = false
                    self.talkButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
        // AVSpeechSynthesizerのインスタンス作成
        self.speechSynthesizer = AVSpeechSynthesizer()
    }
    
    
    
    // MARK: 録音ボタンが押されたら呼ばれる
    @objc func recordButtonTapped(sender: UIButton) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            self.talkButton.isEnabled = false
            self.talkButton.setTitle("Talk", for: .disabled)
            
            //録音が停止した！
            print("録音停止")
            
            //入力された文字列の入った文字列を表示
            // showStrAlert(str: self.voiceStr)
            
            
            
            // ここをコメントを解除する
            // getChat(str: self.voiceStr)
            
            voiceTalk(str: self.voiceStr)
            beforeStr = self.voiceStr
        } else {
            try! startRecording()
            talkButton.setTitle("Stop", for: [])
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
    
    func getChat(str:String) {
        
        let key = "7177626479414562565475376f6c35702e725a396c336f4b7a37486a6a6e79306547626476726977573936"
        let url = "https://api.apigw.smt.docomo.ne.jp/naturalChatting/v1/dialogue?APIKEY=" + key
        let headers: HTTPHeaders = [
            "Contenttype": "application/json"
        ]
        
        let parameters:[String: Any] = [
            "language": "ja-JP",
            "botId": "Chatting",
            "appId": "34060486-3927-45ce-9cff-69a1d22e0b26",
            "voiceText": str,
            "clientData": [
                "option": [
                    "nickname": "アップル",
                    "nicknameY": "ジョブズ",
                    "sex": "女",
                    "bloodtype": "AB",
                    "birthdateY": "2010",
                    "birthdateM": "7",
                    "birthdate": "7",
                    "age": "8",
                    "constellations": "乙女座",
                    "place": "東京",
                    "mode": "dialog"
                ]
            ],
            "appRecvTime": "2018-12-05 13:30:00",
            "appSendTime": "2018-12-05 13:31:00"
        ]
        
        Alamofire.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).responseJSON { response in
            switch response.result {
            case .success:
                let json: JSON = JSON(response.result.value ?? kill)
                print(json["systemText"]["expression"].stringValue)
                self.voiceTalk(str: json["systemText"]["expression"].stringValue)
            case .failure(let error):
                print(error)
            }
            
        }
    
    }
    
    
    //渡された文字列が入ったアラートを表示する
    func voiceTalk(str: String){
        // 読み上げる、文字、言語などの設定
        let utterance = AVSpeechUtterance(string:str) // 読み上げる文字
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP") // 言語
        utterance.rate = 0.5; // 読み上げ速度
        utterance.pitchMultiplier = 1.0; // 読み上げる声のピッチ
        utterance.preUtteranceDelay = 0.2; // 読み上げるまでのため
        self.speechSynthesizer.speak(utterance)
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
                if let range = self.voiceStr.range(of: self.beforeStr) {
                    self.voiceStr.replaceSubrange(range, with: self.beforeStr)
                }
                
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.talkButton.isEnabled = true
                self.talkButton.setTitle("Talk", for: [])
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
            talkButton.isEnabled = true
            talkButton.setTitle("Talk", for: [])
        } else {
            talkButton.isEnabled = false
            talkButton.setTitle("Stop", for: .disabled)
        }
    }
}

