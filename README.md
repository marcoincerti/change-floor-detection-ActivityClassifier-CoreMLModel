# Change Floor Detection

In this university project, I tried to create an **activity classifier model** with machine learning using CreateML. I used the model in an app written in SwiftUI.

The model tries to **classify** the raw data it captures at that instant using also a sliding windows into 4 categories:

- [x] Stay
- [x] Climb
- [x] Descend
- [x] Elevator up
- [x] Elevator down
  
## Step one: Data collection

I know that you need thousands of data to train a good model, but I can't split myself ahah :(
So I downloaded the CoreMotionData Recorder app and started recording data from the **accellerometer**, **gyroscope** and **altimeter** on my cell phone, forcing my family to do it as well.

The data is recorded at a frequency of **50Hz**.
All data collected are from Swift's core Data family.

## Step two: Data Cleaning

In the **prepaire_data.py** file I made a simple script to filter out data that had an incorrect relativeAltitude, I also calculated the differences of the relativeAltitude and pressure so that I had the difference from the previous record.

Finally after a thousand attempts I identified which features are the most relevant and created two folders: the **train** and **test** folders via the turicreate package.
The features I use to train the model are:

- acceleration x (without gravity)
- acceleration v (without gravity)
- acceleration z (without gravity)
- altitude pressure (difference)
- relativeAltitude (difference)
- rotationRate y
- rotationRate v
- rotationRate z

## Step three: Trainig my model
I used Create ML to train and evaluate my model achieving a score of **91 percent. **

**Layer Distribution:**
- 2 x InnerProduct
- 2 x ActivationReLU
- 2 x Slice
- 2 x Concat
- 1 x Convolution
- 1 x Reshape
- 1 x UniDirectionalLSTM
- 1 x BatchNorm
- 1 x Softmax

## Step four: Creation of a very simple app to use the model
I created an app that using the model and relative height calculates what floor you are on starting from the ground floor and identifies how you moved.
