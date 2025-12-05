//
//  ViewController.swift
//  iOSWKWebViewAppTemplateCookiesWorkLikeACharm
//
//  Kingfall V10: 战术休眠与空包弹策略 (Tactical Dormancy & Blank Shot)
//  平衡后台保活与电池寿命，完美解决音乐混音中断问题
//

import UIKit
import WebKit
import AVFoundation

// 👇👇👇【请只修改下面这一行引号里的网址】👇👇👇
let myTargetUrl = "https://ngjgc4ugkxpsxzdxngashmha6bl54s3mrtcbg.netlify.app"
// 👆👆👆【改成你的 AI 聊天网页地址】👆👆👆

class ViewController: UIViewController {
    
    private let webView = WKWebView(frame: .zero)
    // ✅ 战术播放器：只用一次，用完即弃
    var tacticalPlayer: AVAudioPlayer?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. 初始化界面
        setupWebView()
        
        // 2. 发射空包弹：配置会话并“开一枪”以锁定混合模式
        primeAudioSession()
        
        // 3. 监听 App 回到前台，防止配置失效
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    // MARK: - 🎵 Kingfall V10 核心：空包弹策略
    func primeAudioSession() {
        do {
            // A. 强行配置会话：必须是 Playback + MixWithOthers
            let session = AVAudioSession.sharedInstance()
            // 关键：.duckOthers 必须去掉，.defaultToSpeaker 加上防止声音走听筒
            try session.setCategory(.playback, options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)
            
            // B. 动态生成一个 1秒 的极短静音 WAV 文件
            // 目的：不是为了循环播放，而是为了让系统确认“这个 App 确实在用混合模式”
            let sampleRate = 44100.0
            let duration = 1.0 // 只播1秒
            let frameCount = Int(sampleRate * duration)
            let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileUrl = tempDir.appendingPathComponent("kingfall_blank_shot.wav")
            
            if !FileManager.default.fileExists(atPath: fileUrl.path) {
                let audioFile = try AVAudioFile(forWriting: fileUrl, settings: audioFormat.settings)
                if let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)) {
                    buffer.frameLength = AVAudioFrameCount(frameCount)
                    try audioFile.write(from: buffer)
                }
            }
            
            // C. 播放一次，确立主权
            tacticalPlayer = try AVAudioPlayer(contentsOf: fileUrl)
            tacticalPlayer?.numberOfLoops = 0 // ✅ 0 表示不循环，播完就停！省电！
            tacticalPlayer?.volume = 0.01 // 极低音量
            tacticalPlayer?.prepareToPlay()
            tacticalPlayer?.play()
            
            print("✅ Tactical Blank Shot Fired: 混合模式已锁定，原生播放器即将休眠。")
            
        } catch {
            print("❌ Audio Setup Error: \(error)")
        }
    }
    
    // 当 App 每次回到前台时，再次确认音频配置（双重保险）
    @objc func appDidBecomeActive() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ App Active: 音频会话重新激活")
        } catch {
            print("⚠️ Reactivation failed")
        }
    }
    
    // MARK: - WebView Setup
    func setupWebView() {
        view.backgroundColor = .systemBackground
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        self.view.addSubview(self.webView)
        
        NSLayoutConstraint.activate([
            self.webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.webView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.webView.topAnchor.constraint(equalTo: self.view.topAnchor),
        ])
        
        if let url = URL(string: myTargetUrl) {
            let request = URLRequest(url: url)
            webView.load(request)
            
            webView.uiDelegate = self
            webView.navigationDelegate = self
            
            // ✅ 关键设置：允许网页全权控制音频
            webView.configuration.allowsInlineMediaPlayback = true
            webView.configuration.mediaTypesRequiringUserActionForPlayback = []
            
            // 注入 Viewport 适配
            let source: String = "var meta = document.createElement('meta');" +
                "meta.name = 'viewport';" +
                "meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';" +
                "var head = document.getElementsByTagName('head')[0];" +
                "head.appendChild(meta);"
            
            let script: WKUserScript = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(script)
        }
    }
}

// Cookie 保持逻辑 (保持不变)
extension WKWebView {
    enum PrefKey { static let cookie = "cookies" }
    
    func writeDiskCookies(for domain: String, completion: @escaping () -> ()) {
        fetchInMemoryCookies(for: domain) { data in
            UserDefaults.standard.setValue(data, forKey: PrefKey.cookie + domain)
            completion();
        }
    }
    
    func loadDiskCookies(for domain: String, completion: @escaping () -> ()) {
        if let diskCookie = UserDefaults.standard.dictionary(forKey: (PrefKey.cookie + domain)){
            fetchInMemoryCookies(for: domain) { freshCookie in
                let mergedCookie = diskCookie.merging(freshCookie) { (_, new) in new }
                for (_, cookieConfig) in mergedCookie {
                    let cookie = cookieConfig as! Dictionary<String, Any>
                    var expire : Any? = nil
                    if let expireTime = cookie["Expires"] as? Double{
                        expire = Date(timeIntervalSinceNow: expireTime)
                    }
                    let newCookie = HTTPCookie(properties: [
                        .domain: cookie["Domain"] as Any,
                        .path: cookie["Path"] as Any,
                        .name: cookie["Name"] as Any,
                        .value: cookie["Value"] as Any,
                        .secure: cookie["Secure"] as Any,
                        .expires: expire as Any
                    ])
                    if let validCookie = newCookie {
                        self.configuration.websiteDataStore.httpCookieStore.setCookie(validCookie)
                    }
                }
                completion()
            }
        } else {
            completion()
        }
    }
    
    func fetchInMemoryCookies(for domain: String, completion: @escaping ([String: Any]) -> ()) {
        var cookieDict = [String: AnyObject]()
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                if cookie.domain.contains(domain) {
                    cookieDict[cookie.name] = cookie.properties as AnyObject?
                }
            }
            completion(cookieDict)
        }
    }
}

let url = URL(string: myTargetUrl)!

extension ViewController: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let host = url.host {
            webView.loadDiskCookies(for: host){ decisionHandler(.allow) }
        } else { decisionHandler(.allow) }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let host = url.host {
            webView.writeDiskCookies(for: host){ decisionHandler(.allow) }
        } else { decisionHandler(.allow) }
    }
}
