//
//  ContentView.swift
//  change-floor
//
//  Created by Marco Incerti on 21/08/22.
//

import SwiftUI
import CoreML
import CoreMotion

struct ModelConstants {
    static let predictionWindowSize = 200
    static let sensorsUpdateInterval = 1.0 / 50.0
    static let stateInLength = 400
}


class ModelPrediction{
    let activityClassificationModel: changeFloorClassifier27 = try! changeFloorClassifier27(configuration: .init())
    public var currentIndexInPredictionWindow: Int = 0
    
    let accelDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let gyroDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let altitudeRelativeData = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let differenceAltitudeRelativeData = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let differencePressureData = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    //let pressureData = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    var stateOutput = try! MLMultiArray(shape:[ModelConstants.stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    
    
    func performModelPrediction () -> changeFloorClassifier27Output? {
        // Perform model prediction
        let modelPrediction = try! activityClassificationModel.prediction(acceleration_x: accelDataX, acceleration_y: accelDataY, acceleration_z: accelDataZ, differenceAltitude: differenceAltitudeRelativeData, differencePressure: differencePressureData, relativeAltitude: altitudeRelativeData, rotationRate_x:gyroDataX,rotationRate_y: gyroDataY, rotationRate_z: gyroDataZ, stateIn: stateOutput)
        
        // Update the state vector
        stateOutput = modelPrediction.stateOut
        // Return the predicted activity - the activity with the highest probability
        return modelPrediction
    }
    
    func addSampleToDataArray (dataMotion: CMDeviceMotion, relativealtitude: Double, diffRelativealtitude: Double, diff_pressure: Double) -> changeFloorClassifier27Output? {
        // Add the current accelerometer reading to the data array
        accelDataX[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.x as NSNumber
        accelDataY[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.y as NSNumber
        accelDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.z as NSNumber
        
        gyroDataX[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.x as NSNumber
        gyroDataY[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.y as NSNumber
        gyroDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.z as NSNumber
        
        altitudeRelativeData[[currentIndexInPredictionWindow] as [NSNumber]] = relativealtitude as NSNumber
        differenceAltitudeRelativeData[[currentIndexInPredictionWindow] as [NSNumber]] = diffRelativealtitude as NSNumber
        differencePressureData[[currentIndexInPredictionWindow] as [NSNumber]] = diff_pressure as NSNumber
        //pressureData[[currentIndexInPredictionWindow] as [NSNumber]] = pressure as NSNumber
        
        
        // Update the index in the prediction window data array
        currentIndexInPredictionWindow = currentIndexInPredictionWindow + 1
        
        // If the data array is full, call the prediction method to get a new model prediction.
        // We assume here for simplicity that the Gyro data was added to the data arrays as well.
        if (currentIndexInPredictionWindow == ModelConstants.predictionWindowSize) {
            if let predictedActivity = performModelPrediction() {

                currentIndexInPredictionWindow = 0
                return predictedActivity
            }
        }
        return nil
    }
    
}

struct ContentView: View {
    let modelPredict = ModelPrediction()
    let motionManager = CMMotionManager()
    let altimeter = CMAltimeter()
    let height_in_meters = 0.2
    @State var scarto_relative_height = 0.0
    @State var diff_relative_altitude: Double = 0.0
    @State var diff_pressure: Double = 0.0
    @State var relative_altitude: Double = 0.0
    @State var prev_relative: Double = 0.0
    @State var prev_pressure: Double = 0.0
    @State var firstTime = true
    @State var sensor_enable: Bool = false
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State var dict_prob: [String : Double] = ["mhhh":100]
    @State var label_predict: String = "mhhh"
    @State var label_changed: String = "Non hai cambiato piano. "
    @State var floor : Int = 0
    
    func check_floor() {
        if abs(relative_altitude) > height_in_meters - (height_in_meters * 0.2){
            print(relative_altitude, scarto_relative_height)
            label_changed = "Hai cambiato piano usando \(label_predict). "
            if relative_altitude > 0 {
                floor = floor + 1
            }else {
                floor = floor - 1
            }
            scarto_relative_height = scarto_relative_height + relative_altitude
            //relative_altitude = relative_altitude - scarto_relative_height
        }
    }
    
    func startSensors() {
        guard motionManager.isAccelerometerAvailable, motionManager.isGyroAvailable, motionManager.isDeviceMotionAvailable, CMAltimeter.isRelativeAltitudeAvailable() else { return }
        
        motionManager.accelerometerUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.gyroUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.deviceMotionUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        
        altimeter.startRelativeAltitudeUpdates(to: .main){ dataAltimeter, error in
            guard let dataAltimeter = dataAltimeter else {  return }
            relative_altitude = (dataAltimeter.relativeAltitude as! Double) - scarto_relative_height
            let pressure = dataAltimeter.pressure as! Double
            
            if firstTime{
                prev_pressure = pressure
                prev_relative = relative_altitude
                firstTime = false
            } else {
                if relative_altitude !=  prev_relative{
                    diff_relative_altitude = relative_altitude - prev_relative
                    prev_relative = relative_altitude
                }
                
                if pressure !=  prev_pressure {
                    diff_pressure = pressure - prev_pressure
                    prev_pressure = pressure
                }
            }
        }
        
        motionManager.startDeviceMotionUpdates(to: .main){ dataMotion, error in
            guard let dataMotion = dataMotion else { return }
            //print(dataMotion.userAcceleration.x, dataMotion.userAcceleration.y, dataMotion.userAcceleration.z)
            guard let data = modelPredict.addSampleToDataArray(dataMotion: dataMotion, relativealtitude: relative_altitude, diffRelativealtitude: diff_relative_altitude, diff_pressure: diff_pressure) else { return }
            dict_prob = data.labelProbability
            label_predict = data.label
        }
        
    }
    
    func stopSensor(){
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        modelPredict.currentIndexInPredictionWindow = 0
        dict_prob = ["mhhh":100]
        label_predict = "mhhh"
    }
    
    var body: some View {
        VStack{
            Text(String(label_predict))
                .padding()
            Text(label_changed + "Sei al piano: \(floor)")
                .padding()
                .onReceive(timer) { time in
                                check_floor()
                            }
            Text("\(relative_altitude)")
                .padding()
            List {
                ForEach(dict_prob.sorted(by: >), id: \.key) { key, value in
                    Section(header: Text(key)) {
                        Text(String(value))
                    }
                }
            }
            
            Button(action: {
                if sensor_enable{
                    self.stopSensor()
                }else{
                    self.startSensors()
                }
                
                sensor_enable = !sensor_enable
            }) {
                if sensor_enable{
                    Text("Stop")
                }else{
                    Text("Go")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
