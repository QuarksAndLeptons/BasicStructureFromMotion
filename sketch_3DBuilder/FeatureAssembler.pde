import java.util.LinkedList;

public class FeatureAssembler {
  public ArrayList<AnnotatedView> views;
  private PointCloudWriter output;
  int currentIndex;

  public FeatureAssembler() {
    views = new ArrayList<AnnotatedView>();
  }

  public FeatureAssembler(FeatureExtractor[] featureExtractors) {
    views = new ArrayList<AnnotatedView>();
    for (FeatureExtractor f : featureExtractors) {
      AnnotatedView newView = new AnnotatedView(f);
      views.add(newView);
    }
  }

  public void addView(FeatureExtractor featureExtractor) {
    views.add(new AnnotatedView(featureExtractor));
  }
  public void addView(String inputFilename) {
    views.add(new AnnotatedView(inputFilename));
  }

  public FeatureAssembler(String[] inputViewFiles) {
    for (String s : inputViewFiles) {
      AnnotatedView newView = new AnnotatedView(s);
      views.add(newView);
    }
  }

  private class PointCloudGeneratorThread extends Thread {
    public void run() {
      while (currentIndex<views.size()-1) {
        generatePointCloud();
      }
    }

    private void generatePointCloud() {
      int i = ++currentIndex;
      int pointCount = 0;
      print("\tProcessing view ");
      print(i);
      print(" of ");
      println(views.size());
      int t = millis();

      AnnotatedView a = views.get(i);
      for (Feature f : a.features) {
        //Find the closest point to this one
        Feature closest = null;
        float minDistance = Float.POSITIVE_INFINITY;
        float highestSimilarity = 0.6;

        for (int j = i+1; j < views.size(); j++) {
          AnnotatedView b = views.get(j);

          //Don't include views that are really close to each other; the parallax between them is too few
          if (a.coordinates.angle(b.coordinates)<PI/8.0) continue;

          for (Feature g : b.features) {
            float newDistance = f.distanceFrom(g);
            if (f.distanceFrom(g)<minDistance) {
              
              float newSimilarity = getSimilarity(a.image, int(f.positionInImage.x), int(f.positionInImage.y), b.image, int(g.positionInImage.x), int(g.positionInImage.y), 8);

              //Check if the points look similar. If they don't these points don't really match
              if (newSimilarity>highestSimilarity) {
                closest = g;
                minDistance=newDistance;
                highestSimilarity = newSimilarity;
              }
            }//end if
          }//end for
        }//end for
        if (closest!=null) {
          output.printVector(f.estimatePosition(closest));
          pointCount++;
        }
      }//end for
      print("\tDone processing view ");
      print(i);
      print(" of ");
      println(views.size());
      print("\t\tTime (ms): ");
      println(millis()-t);
      print("\t\tPoints found: ");
      print(pointCount);
      print(" of ");
      println(a.features.size());
    }//end generatePointCloud
  }





  public void generatePointCloud(String extensionlessOutputFileName, int numberOfThreads) {
    //Write to file
    int time = millis();
    print("Assembling has begun with ");
    print(numberOfThreads);
    println(" threads");
    output = new PointCloudWriter(extensionlessOutputFileName);
    currentIndex = 0;
    Thread[] threads = new Thread[numberOfThreads];
    for (int i = 0; i < numberOfThreads; i++) {
      threads[i] = new PointCloudGeneratorThread();
      threads[i].start();
      delay(100);
    }
    boolean threadStillRunning = true;
    while(threadStillRunning) {
      threadStillRunning = false;
      for (int i = 0; i < numberOfThreads; i++) {
        if(threads[i].isAlive()) threadStillRunning = true;
      }
      delay(500);
    }
    output.close();
    print("Done processing. (time :");
    print(millis()-time);
    println(" milliseconds)");
  }
}



public class AnnotatedView {
  CameraCoordinates coordinates;
  LinkedList<Feature> features;
  PImage image;

  public AnnotatedView(FeatureExtractor featureExtractor) {
    coordinates = featureExtractor.coordinates;
    if (featureExtractor.features==null) featureExtractor.loadAllFeaturesFromImage();
    features = featureExtractor.features;
    image = featureExtractor.image;
  }
  public AnnotatedView(String inputFileName) {
    loadFeaturesFromFile(inputFileName);
  }
  public AnnotatedView(PImage image, PVector cameraPosition, PVector cameraDirection) {
    throw new UnsupportedOperationException("Method not implemented yet!");
  }
  public AnnotatedView(PImage image, CameraCoordinates cameraCoordinates) {
    throw new UnsupportedOperationException("Method not implemented yet!");
  }

  private void loadFeaturesFromFile(String inputFileName) {
    String[] lines = loadStrings(inputFileName);
    for (int i = 2; i < lines.length; i++) {
      Feature newFeature = new Feature(lines[0], lines[1], lines[i]);
      features.add(newFeature);
    }
  }
}
