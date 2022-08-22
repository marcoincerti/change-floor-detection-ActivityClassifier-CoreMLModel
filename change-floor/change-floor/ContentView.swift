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
    static let predictionWindowSize = 150
    static let sensorsUpdateInterval = 1.0 / 50.0
    static let stateInLength = 400
}


class ModelPrediction{
    let activityClassificationModel: MyActivityClassifier_9 = try! MyActivityClassifier_9(configuration: .init())
    public var currentIndexInPredictionWindow: Int = 0
    
    let accelDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let gyroDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let altitudeRelativeData = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let pressureData = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    var stateOutput = try! MLMultiArray(shape:[ModelConstants.stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    
    
    func performModelPrediction () -> [String : Double]? {
        // Perform model prediction
        let modelPrediction = try! activityClassificationModel.prediction(acceleration_x: accelDataX, acceleration_y: accelDataY, acceleration_z: accelDataZ, altitude_pressure: pressureData, relativeAltitude: altitudeRelativeData, rotationRate_x: gyroDataX, rotationRate_y: gyroDataY, rotationRate_z:gyroDataZ, stateIn: stateOutput)
        
        // Update the state vector
        stateOutput = modelPrediction.stateOut
        print(modelPrediction.labelProbability)
        // Return the predicted activity - the activity with the highest probability
        return modelPrediction.labelProbability
    }
    
    func addSampleToDataArray (dataMotion: CMDeviceMotion, relativeAltitude: Double, pressure: Double) -> [String : Double]? {
        // Add the current accelerometer reading to the data array
        accelDataX[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.x as NSNumber
        accelDataY[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.y as NSNumber
        accelDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.z as NSNumber
        
        gyroDataX[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.x as NSNumber
        gyroDataY[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.y as NSNumber
        gyroDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.z as NSNumber
        
        altitudeRelativeData[[currentIndexInPredictionWindow] as [NSNumber]] = relativeAltitude as NSNumber
        pressureData[[currentIndexInPredictionWindow] as [NSNumber]] = pressure as NSNumber
        
        
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
    @State var relativealtitude: Double = 0.0
    @State var pressure: Double = 0.0
    @State var prev_pressure: Double = 0.0
    @State var firstTime = true
    
    @State var label: [String : Double] = ["mhhh":100]
    
    func startSensors() {
        guard motionManager.isAccelerometerAvailable, motionManager.isGyroAvailable, motionManager.isDeviceMotionAvailable, CMAltimeter.isRelativeAltitudeAvailable() else { return }
        
        motionManager.accelerometerUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.gyroUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.deviceMotionUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        
        altimeter.startRelativeAltitudeUpdates(to: .main){ dataAltimeter, error in
            guard let dataAltimeter = dataAltimeter else {  return }
            
            let tmp_altitude = dataAltimeter.relativeAltitude as! Double
            let tmp_pressure = dataAltimeter.pressure as! Double
            
            if tmp_altitude - relativealtitude != 0{
                relativealtitude = tmp_altitude - relativealtitude
            }
            
            if firstTime {
                prev_pressure = tmp_pressure
                firstTime = false
            }
            
            if tmp_pressure - prev_pressure != 0{
                pressure = tmp_pressure - prev_pressure
                prev_pressure = tmp_pressure
            }
        }
        
        motionManager.startDeviceMotionUpdates(to: .main){ dataMotion, error in
            guard let dataMotion = dataMotion else { return }
            print(relativealtitude, pressure)
            guard let data = modelPredict.addSampleToDataArray(dataMotion: dataMotion, relativeAltitude: relativealtitude, pressure: pressure) else { return }
            label = data
            print(label)
        }
        
    }
    
    var body: some View {
        VStack{
            List {
                ForEach(label.sorted(by: >), id: \.key) { key, value in
                    Section(header: Text(key)) {
                        Text(String(value))
                    }
                }
            }
            
            Button(action: {
                self.startSensors()
            }) {
                Text("Go")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
