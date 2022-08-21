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


struct ContentView: View {
    let activityClassificationModel: MyActivityClassifier_10 = try! MyActivityClassifier_10(configuration: .init())
    @State var currentIndexInPredictionWindow = 0
    @State var labelPredict = ""
    
    let accelDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let accelDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let gyroDataX = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataY = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let gyroDataZ = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    let attitudeDataPitch = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let attitudeDataRoll = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    let attitudeDataYaw = try! MLMultiArray(shape: [ModelConstants.predictionWindowSize] as [NSNumber], dataType: MLMultiArrayDataType.double)
    
    @State var stateOutput = try! MLMultiArray(shape:[ModelConstants.stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    let motionManager = CMMotionManager()
    
    
    func performModelPrediction () -> String? {
        // Perform model prediction
        let modelPrediction = try! activityClassificationModel.prediction(acceleration_x: accelDataX, acceleration_y: accelDataY, acceleration_z: accelDataZ, attitude_pitch: attitudeDataPitch, attitude_roll: attitudeDataRoll, attitude_yaw: attitudeDataYaw, rotationRate_x: gyroDataX, rotationRate_y: gyroDataY, rotationRate_z: gyroDataZ, stateIn: stateOutput)

        // Update the state vector
        stateOutput = modelPrediction.stateOut

        // Return the predicted activity - the activity with the highest probability
        return modelPrediction.label
    }
    
    func addSampleToDataArray (accelSample: CMAccelerometerData, gyroSample: CMGyroData, attSample: CMDeviceMotion) {
        // Add the current accelerometer reading to the data array
        accelDataX[[currentIndexInPredictionWindow] as [NSNumber]] = accelSample.acceleration.x as NSNumber
        accelDataY[[currentIndexInPredictionWindow] as [NSNumber]] = accelSample.acceleration.y as NSNumber
        accelDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = accelSample.acceleration.z as NSNumber
        
        gyroDataX[[currentIndexInPredictionWindow] as [NSNumber]] = gyroSample.rotationRate.x as NSNumber
        gyroDataY[[currentIndexInPredictionWindow] as [NSNumber]] = gyroSample.rotationRate.y as NSNumber
        gyroDataZ[[currentIndexInPredictionWindow] as [NSNumber]] = gyroSample.rotationRate.z as NSNumber
        
        attitudeDataPitch[[currentIndexInPredictionWindow] as [NSNumber]] = attSample.attitude.pitch as NSNumber
        attitudeDataRoll[[currentIndexInPredictionWindow] as [NSNumber]] = attSample.attitude.roll as NSNumber
        attitudeDataYaw[[currentIndexInPredictionWindow] as [NSNumber]] = attSample.attitude.yaw as NSNumber

        // Update the index in the prediction window data array
        currentIndexInPredictionWindow += 1

        // If the data array is full, call the prediction method to get a new model prediction.
        // We assume here for simplicity that the Gyro data was added to the data arrays as well.
        if (currentIndexInPredictionWindow == ModelConstants.predictionWindowSize) {
            if let predictedActivity = performModelPrediction() {

                labelPredict = predictedActivity
                // Start a new prediction window
                currentIndexInPredictionWindow = 0
            }
        }
    }
    
    func startSensors() {
        guard motionManager.isAccelerometerAvailable, motionManager.isGyroAvailable, motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.gyroUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        motionManager.deviceMotionUpdateInterval = TimeInterval(ModelConstants.sensorsUpdateInterval)
        
        var dataAcc:CMAccelerometerData = CMAccelerometerData()
        var dataGyro:CMGyroData = CMGyroData()
        var dataAtt:CMDeviceMotion = CMDeviceMotion()
        
        
        motionManager.startAccelerometerUpdates(to: .main) { accelerometerData, error in
            guard let accelerometerData = accelerometerData else { return }
            dataAcc = accelerometerData
        }
        
        motionManager.startGyroUpdates(to: .main) { gyroData, error in
            guard let gyroData = gyroData else { return }
            dataGyro = gyroData
        }
        
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main){ attitudineData, error in
            guard let attitudineData = attitudineData else { return }
            dataAtt = attitudineData
        }
        
        
        // Add the current data sample to the data array
        self.addSampleToDataArray(accelSample: dataAcc, gyroSample: dataGyro, attSample: dataAtt)
    }
    
    var body: some View {
        Text(labelPredict)
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
