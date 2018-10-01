
//
//  ViewController+Background.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 25.02.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa
import AudioKit

extension ViewController {    
    func endTask() {
        self._workerSemaphore.signal()
    }
    
    func startBackgroundTasks() {
        self.backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true ) { [unowned self] (timer) in
            if self.view.window?.isVisible ?? false {
                // Main Window Visuals
                self._waveformView.updateLocation(by: self.player.player, duration: CMTime(seconds: 1.0 / 10.0, preferredTimescale: 1000))
                
                self._taskButton.spinning = !(self.runningTasks.isEmpty && self.tasker.queue.isEmpty)
                
                if !self._timePlayed.isHidden, !self._timeLeft.isHidden {
                    self._timePlayed.stringValue = Int(self.player.player.currentTime).timeString
                    self._timeLeft.stringValue = Int(self.player.player.duration - self.player.player.currentTime).timeString
                }
            }
            
            // Create specific tasks
            Library.shared.considerExport()
            Library.shared.considerSanity()
            
            // Sanity check audio player
            if self.player.isPlaying {
                self.player.sanityCheck()
            }

            // Run Tasks
            var taskers = PriorityQueue(ascending: true, startingValues: self.taskers)
            taskers.push(self.tasker)
            var haveWorkerKey = false
            
            while let tasker = taskers.pop(), let promise = tasker.promise {
                // Have a tasker that promises some task
                
                // If no worker key acquired yet, acquire one now
                haveWorkerKey = haveWorkerKey || self._workerSemaphore.acquireNow()
                if haveWorkerKey || promise <= 0 {
                    // We want a new task!
                    if let task = tasker.spawn(running: self.runningTasks) {
                        // TODO Might have changed the view!
                        self.runningTasks.append(task)
                        self.taskViewController.reload()

                        // Task delivar'd, execute!
                        task.completion = { [unowned self, haveWorkerKey] in
                            if haveWorkerKey {
                                self._workerSemaphore.signal()
                            }
                            
                            DispatchQueue.main.async{
                                self.runningTasks.remove(element: task)
                                self.taskViewController.reload()
                            }
                        }
                        task.execute()
                        haveWorkerKey = false
                        
                        if tasker.promise != nil {
                            // Tasker promises a new task, push back onto queue
                            taskers.push(tasker)
                        }
                    }
                    // Else the task has not delivar'd
                    // continue with popping the next tasker
                }
                else {
                    // No worker keys left and task doesn't warrant spawning a new one
                    break
                }
            }
            
            if haveWorkerKey {
                // Looks like we prematurely grabbed a key, give back
                self._workerSemaphore.signal()
            }
        }
        
        // Requests are freaking slow with many tracks so do it rarely
        Timer.scheduledAsyncTickTock(withTimeInterval: 5, do: [{
            Library.shared.performChildBackgroundTask { mox in
                let metadataRequest: NSFetchRequest = Track.fetchRequest()
                metadataRequest.predicate = NSPredicate(format: "metadataFetchDate == nil")
                metadataRequest.fetchLimit = 200
                let asyncTracks = try! mox.fetch(metadataRequest)
                    .filter { $0.url != nil }
                
                // Need to do this in sync because we use tasker.enqueue
                DispatchQueue.main.async {
                    for track in Library.shared.viewContext.compactConvert(asyncTracks) {
                        self.tasker.enqueue(task: FetchTrackMetadata(track: track))
                    }
                }
            }
            }, {
                guard Preferences.AnalyzeNewTracks.current == .analyze else {
                    return
                }
                
                Library.shared.performChildBackgroundTask { mox in
                    let analysisRequest: NSFetchRequest = TrackVisuals.fetchRequest()
                    analysisRequest.predicate = NSPredicate(format: "analysis == nil")
                    analysisRequest.fetchLimit = 20
                    let asyncTracks = try! mox.fetch(analysisRequest)
                        .compactMap { $0.track }
                        .filter { $0.url != nil }

                    // Need to do this in sync because we use tasker.enqueue
                    DispatchQueue.main.async {
                        for track in Library.shared.viewContext.compactConvert(asyncTracks) {
                            self.tasker.enqueue(task: AnalyzeTrack(track: track, read: true))
                        }
                    }
                }
            }])
    }
}
