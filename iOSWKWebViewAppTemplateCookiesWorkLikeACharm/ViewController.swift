//
//  ViewController.swift
//  iOSWKWebViewAppTemplateCookiesWorkLikeACharm
//
//  Kingfall V8: 纯净混音修复版 (No Ducking, Pure Mixing)
//

import UIKit
import WebKit
import AVFoundation // 核心音频框架

// 👇👇👇【请只修改下面这一行引号里的网址】👇👇👇
let myTargetUrl = "https://ngjgc4ugkxpsxzdxngashmha6bl54s3mrtcbg.netlify.app"
// 👆👆👆【改成你的 AI 聊天网页地址】👆👆👆

class ViewController: UIViewController {
    
    private let webView = WKWebView(frame: .zero)
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // --- ✅【Kingfall 核心修复】音频会话配置 V8 ---
        do {
            // 1. 获取音频会话单例
            let audioSession = AVAudioSession.sharedInstance()
            
            // 2. 设置 Category 为 Playback
            //    原因：只有 Playback 才能在锁屏/后台时保持 App 运行。
            // 3. 设置 Options 为 .mixWithOthers
            //    关键点：这里去掉了 .duckOthers，确保不降低背景音乐音量。
            //    关键点：.mixWithOthers 确保 App 音频与网易云音乐共存，而不是打断它。
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            
            // 4. 激活会话
            try audioSession.setActive(true)
            
            print("✅ Audio Session Configured: Playback + MixWithOthers (No Ducking)")
        } catch {
            print("❌ Failed to configure Audio Session: \(error)")
        }
        // -----------------------------------------------------------
        
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
            
            // --- ✅【网页媒体权限增强】 ---
            // 允许网页不经过用户点击就能自动播放音频（防止静音脚本被拦截）
            webView.configuration.mediaTypesRequiringUserActionForPlayback = []
            // 允许内联播放，防止全屏播放器弹出
            webView.configuration.allowsInlineMediaPlayback = true
            // 允许画中画（虽然静音音频用不到，但能增加保活权重）
            webView.configuration.allowsPictureInPictureMediaPlayback = true
            
            // 注入 Viewport 适配代码
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

// 下面是 Cookie 持久化逻辑，保持不变
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
