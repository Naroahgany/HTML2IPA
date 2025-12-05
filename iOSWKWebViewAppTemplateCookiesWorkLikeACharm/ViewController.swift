//
//  ViewController.swift
//  iOSWKWebViewAppTemplateCookiesWorkLikeACharm
//
//  Kingfall Ultra Fix: 全屏沉浸式 PWA 专用版
//  1. 移除所有手动状态栏遮罩，实现完全透明。
//  2. 启用 viewport-fit=cover，完美适配刘海屏和底部 Home 条。
//  3. 自动适配深色模式状态栏文字颜色。
//

import UIKit
import WebKit

// 👇👇👇【请只修改下面这一行引号里的网址】👇👇👇
let myTargetUrl = "https://ngjgc4ugkxpsxzdxngashmha6bl54s3mrtcbg.netlify.app" 
// 👆👆👆【改成你的 AI 聊天网页地址】👆👆👆

class ViewController: UIViewController {
    
    private let webView = WKWebView(frame: .zero)
    
    // 让状态栏文字颜色跟随系统深色/浅色模式自动切换
    // 如果系统是深色模式，文字变白；系统是浅色，文字变黑。
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置背景色为跟随系统（避免网页加载前闪烁白屏）
        view.backgroundColor = .systemBackground
        
        // --- 核心修改：移除所有手动添加的 statusbarView ---
        
        // 配置 Webview 布局
        webView.translatesAutoresizingMaskIntoConstraints = false
        // 允许 Webview 透明，透出底色
        webView.isOpaque = false 
        webView.backgroundColor = .systemBackground
        
        // 【重要】告诉 Webview 不要自动给刘海和底部留白，让网页 CSS 的 env(safe-area-inset) 生效
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        self.view.addSubview(self.webView)
        
        // --- 核心修改：强制铺满整个屏幕（不留任何边距）---
        NSLayoutConstraint.activate([
            // 紧贴屏幕最边缘，而不是 safeAreaLayoutGuide
            self.webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            self.webView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.webView.topAnchor.constraint(equalTo: self.view.topAnchor),
        ])
        
        // 加载网页
        if let url = URL(string: myTargetUrl) {
            let request = URLRequest(url: url)
            webView.load(request)
            
            webView.uiDelegate = self
            webView.navigationDelegate = self
            
            // --- 注入修正后的 Viewport 脚本 ---
            // 增加了 'viewport-fit=cover'，这是 PWA 全屏适配的关键
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

// Cookie 保持功能的扩展代码（保持不变，这部分是好的）
extension WKWebView {
    
    enum PrefKey {
        static let cookie = "cookies"
    }
    
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

// 全局 URL 引用
let url = URL(string: myTargetUrl)!

extension ViewController: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let host = url.host {
            webView.loadDiskCookies(for: host){
                decisionHandler(.allow)
            }
        } else {
             decisionHandler(.allow)
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let host = url.host {
            webView.writeDiskCookies(for: host){
                decisionHandler(.allow)
            }
        } else {
            decisionHandler(.allow)
        }
    }
}
