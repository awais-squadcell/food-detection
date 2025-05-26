let model;

async function loadModel() {
  if (!model) {
    model = await tf.loadLayersModel('tfjs/model.json');
  }
}

async function predictBase64Image(base64Image, callback) {
  await loadModel();

  const img = new Image();
  img.crossOrigin = "anonymous";

  img.onload = async () => {
    const tensor = tf.browser.fromPixels(img)
      .resizeNearestNeighbor([224, 224])
      .toFloat()
      .div(tf.scalar(255.0))
      .expandDims(0);

    const predictions = await model.predict(tensor).data();

    // Convert to plain Array
    const resultArray = Array.from(predictions);

    // Return array to Dart
    callback(resultArray);
  };

  img.src = base64Image;
}

