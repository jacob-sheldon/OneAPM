//
//  StutterMonitor.swift
//  OneAPM
//
//  Created by 施治昂 on 9/12/23.
//

import Foundation

@objc
public class StutterMonitor : NSObject {
    
    private let stutterMonitorQueue = DispatchQueue(label: "stutter-monitor", qos: .background, autoreleaseFrequency: .inherit)
    private let sempahore = DispatchSemaphore(value: 0)
    private var receiveSignal = false
    private let lock = NSLock()
    private let timeThreshold = 0.4
    
    @objc
    func start() {
        stutterMonitorQueue.async { [unowned self] in
            while true {
                self.lock.lock()
                self.receiveSignal = false
                self.lock.unlock()
                
                DispatchQueue.main.async { [unowned self] in
                    self.lock.lock()
                    self.receiveSignal = true
                    self.lock.unlock()
                }
                
                Thread.sleep(forTimeInterval: self.timeThreshold)
                
                if self.receiveSignal == false {
                    print("发生了卡顿")
                } else {
                    print("没有卡顿")
                }
                
                self.sempahore.wait()
            }
        }
    }
}
