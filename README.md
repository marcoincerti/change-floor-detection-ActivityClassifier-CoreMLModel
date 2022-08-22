# Change Floor Detection

In this university project, I tried to create an **activity classifier model** with machine learning using CreateML. I used the model in an app written in SwiftUI.

The model tries to **classify** the raw data it captures at that instant using also a sliding windows into 4 categories:

- [x] Stay
- [x] Climb
- [x] Descend
- [] Elevator up
- [] Elevator down
  
## Step one: Data collection

I know that you need thousands of data to train a good model, but I can't split myself ahah :(
So I downloaded the CoreMotionData Recorder app and started recording data from the accellerometer and altimeter on my cell phone, forcing my family to do it as well.

The data is recorded at a frequency of 50Hz.
All data collected are from Swift's core Data family.

## Step two: DataCleaning

In the prepari_data.py file I made a simple script to filter out data that had an incorrect relativeAltitude, I also calculated the differences of the relativeAltitude and pressure so that I had the difference from the previous record.

Finally after a thousand attempts I identified which features are the most relevant and created two folders: the train and test folders via the turicreate package. 
