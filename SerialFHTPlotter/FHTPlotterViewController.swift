//
//  ViewController.swift
//  SerialFHTPlotter
//
//  Created by Nevyn Bengtsson on 2016-08-23.
//  Copyright © 2016 ThirdCog. All rights reserved.
//

import Cocoa

class FHTPlotterViewController: NSViewController, CPTPlotDataSource, ORSSerialPortDelegate {

    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var graphView: CPTGraphHostingView!
    
    static let high = 255;
    static let low = 0;
    static let range = high - low;
    static let sampleCount = 128;
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        for _ in 0...255 {
            data.append(0)
        }
        
        setupGraph()
        setupSerial()
    }
    
    func setupGraph()
    {
        let graph = CPTXYGraph(frame:CGRectZero)

        let dataSourceLinePlot = CPTScatterPlot(frame: graph.bounds)
        dataSourceLinePlot.identifier = "Data Source Plot"
        dataSourceLinePlot.dataSource = self
        graph.addPlot(dataSourceLinePlot)

        self.graphView.hostedGraph = graph;

        let plotSpace = graph.defaultPlotSpace as! CPTXYPlotSpace
        
        
        
        plotSpace.xRange = CPTPlotRange(location: 0, length: FHTPlotterViewController.sampleCount)
        plotSpace.yRange = CPTPlotRange(location: FHTPlotterViewController.low, length: FHTPlotterViewController.range)
        
        let axisSet = graph.axisSet as! CPTXYAxisSet

        let x = axisSet.xAxis!
        x.majorIntervalLength   = 10.0
        x.orthogonalPosition    = 0.0
        x.minorTicksPerInterval = 1

        let y  = axisSet.yAxis!
        y.majorIntervalLength = 64
        y.minorTicksPerInterval = 4
        y.orthogonalPosition    = 0
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func numberOfRecordsForPlot(plot: CPTPlot) -> UInt {
        return UInt(FHTPlotterViewController.sampleCount);
    }
    
    var data : [UInt] = []
    
    func numberForPlot(plot: CPTPlot, field fieldEnum: UInt, recordIndex idx: UInt) -> AnyObject?
    {
        if fieldEnum == UInt(CPTScatterPlotField.X.rawValue) {
            return idx;
        } else {
            return data[Int(idx)];
        }
    }
    
    var port : ORSSerialPort?
    func setupSerial()
    {
        NSNotificationCenter.defaultCenter().addObserverForName(ORSSerialPortsWereConnectedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { (notif) in
            let port = notif.userInfo![ORSConnectedSerialPortsKey] as! ORSSerialPort
            self.maybeUsePort(port)
        }
        for port in ORSSerialPortManager.sharedSerialPortManager().availablePorts {
            maybeUsePort(port)
        }
    }
    
    func maybeUsePort(port : ORSSerialPort) {
        if self.port == nil && port.path.containsString("usbserial") {
            self.port = port
            port.baudRate = 115200
            port.open()
            port.delegate = self
            self.graphView.hostedGraph?.reloadData()
            self.statusLabel.stringValue = "connected to \(port.path)"
        }
    }
    
    func stopUsingPort() {
        self.port?.close()
        self.port?.delegate = nil
        self.port = nil
        for _ in 0..<255 {
            self.data.append(0)
        }
        self.graphView.hostedGraph?.reloadData()
        self.statusLabel.stringValue = "disconnected"
    }
    
    var lastIndex: Int = 0
    
    func serialPort(serialPort: ORSSerialPort, didReceiveData data: NSData) {
        let incoming = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length))
        for x in incoming {
            if x == 255 || lastIndex == FHTPlotterViewController.sampleCount {
                lastIndex = 0
                self.graphView.hostedGraph?.reloadData()
                continue
            }
            self.data[lastIndex] = UInt(x)
            lastIndex += 1
        }
    }
    
    func serialPortWasRemovedFromSystem(serialPort: ORSSerialPort) {
        stopUsingPort()
    }
}

