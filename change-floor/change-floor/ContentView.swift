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
    let activityClassificationModel: MyActivityClassifier4 = try! MyActivityClassifier4(configuration: .init())
    public var currentIndexInPredictionWindow: Int = 0
    
    let accelDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let gyroDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let attitudeDataPitch = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let attitudeDataRoll = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let attitudeDataYaw = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    var stateOutput = try! MLMultiArray(shape:[ModelConstants.stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    
    
    func performModelPrediction () -> [String : Double]? {
        // Perform model prediction
        let modelPrediction = try! activityClassificationModel.prediction(acceleration_x: accelDataX, acceleration_y: accelDataY, acceleration_z: accelDataZ, attitude_pitch: attitudeDataPitch, attitude_roll: attitudeDataRoll, attitude_yaw: attitudeDataYaw, rotationRate_x: gyroDataX, rotationRate_y: gyroDataY, rotationRate_z: gyroDataZ, stateIn: stateOutput)
        
        // Update the state vector
        stateOutput = modelPrediction.stateOut
        print(modelPrediction.labelProbability)
        // Return the predicted activity - the activity with the highest probability
        return modelPrediction.labelProbability
    }
    
    func addSampleToDataArray (dataMotion: CMDeviceMotion) -> [String : Double]? {
        // Add the current accelerometer reading to the data array
        print(dataMotion.userAcceleration)
        accelDataX[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.x as NSNumber
        accelDataY[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.y as NSNumber
        accelDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.userAcceleration.z as NSNumber
        
        gyroDataX[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.x as NSNumber
        gyroDataY[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.y as NSNumber
        gyroDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.rotationRate.z as NSNumber
        
        //print(dataMotion.attitude)
        attitudeDataPitch[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.attitude.pitch as NSNumber
        attitudeDataRoll[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.attitude.roll as NSNumber
        attitudeDataYaw[[currentIndexInPredictionWindow] as [NSNumber]] = dataMotion.attitude.yaw as NSNumber
        
        // Update the index in the prediction window data array
        currentIndexInPredictionWindow = currentIndexInPredictionWindow + 1
        
        // If the data array is full, call the prediction method to get a new model prediction.
        // We assume here for simplicity that the Gyro data was added to the data arrays as well.
//        if (currentIndexInPredictionWindow == ModelConstants.predictionWindowSize) {
//            if let predictedActivity = performModelPrediction() {
//
//                currentIndexInPredictionWindow = 0
//                return predictedActivity
//            }
//        }
        return nil
    }
    
}

struct ContentView: View {
    let modelPredict = ModelPrediction()
    let motionManager = CMMotionManager()
    @State var label: [String : Double] = ["mhhh":100]
    
    func startSensors() {
        guard motionManager.isAccelerometerAvailable, motionManager.isGyroAvailable, motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.gyroUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.deviceMotionUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main){ dataMotion, error in
            guard let dataMotion = dataMotion else { return }
            guard let data = modelPredict.addSampleToDataArray(dataMotion: dataMotion) else { return }
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
