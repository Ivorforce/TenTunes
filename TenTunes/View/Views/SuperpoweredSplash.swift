//
//  SuperpoweredSplash.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 02.10.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa
import WebKit

class SuperpoweredSplash: NSView {
    class func show(in view: NSView) {
        let webView = WKWebView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        webView.setValue(false, forKey: "drawsBackground")
        
        let splashURL = Bundle.main.url(forResource: "superpowered_splash.svg", withExtension: nil)!
        webView.loadHTMLString("""
<body style="background-color: #95D5F3;">
<center><img src="superpowered_splash.svg"></center>
</body>
""", baseURL: splashURL.deletingLastPathComponent())

        webView.frame = view.bounds
        view.addSubview(webView)
        view.addConstraints(NSLayoutConstraint.copyLayout(from: view, for: webView))
        
        Timer.scheduledAsyncBlock(withTimeInterval: 3.7, repeats: false) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                webView.animator().alphaValue = 0
            }) {
                webView.removeFromSuperview()
            }
        }
    }
}
