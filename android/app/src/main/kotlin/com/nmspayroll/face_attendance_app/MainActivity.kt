package com.nmspayroll.face_attendance_app

import android.content.res.AssetFileDescriptor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nmspayroll.face/recognition"
    private var tfliteInterpreter: Interpreter? = null
    
    // Standard MobileFaceNet input size is often 112. FaceNet is often 160.
    // We will attempt to read input shape from model if possible, or default to 112.
    private var inputSize = 112
    private var outputSize = 128 // Default embedding size (will adjust dynamically)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Executors.newSingleThreadExecutor().execute {
            try {
                initInterpreter()
            } catch (e: Exception) {
                android.util.Log.e("FaceEmbedder", "Error initializing TFLite: ${e.message}")
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getFaceEmbedding") {
                val imageBytes = call.argument<ByteArray>("image")
                if (imageBytes != null) {
                    try {
                        val embedding = runInference(imageBytes)
                        if (embedding != null) {
                            result.success(embedding)
                        } else {
                            result.error("FAILURE", "Could not generate embedding", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Inference failed: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Image data is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun initInterpreter() {
        val model = loadModelFile("face_embedder.tflite")
        val options = Interpreter.Options()
        tfliteInterpreter = Interpreter(model, options)

        // Inspect model to determine input/output shapes
        val inputTensor = tfliteInterpreter?.getInputTensor(0)
        val outputTensor = tfliteInterpreter?.getOutputTensor(0)

        // Assuming shape comes as [1, height, width, 3]
        if (inputTensor != null && inputTensor.shape().size == 4) {
            inputSize = inputTensor.shape()[1] // Take height
            android.util.Log.d("FaceEmbedder", "Detected Input Size: $inputSize")
        }

        if (outputTensor != null && outputTensor.shape().isNotEmpty()) {
            outputSize = outputTensor.shape().last()
            android.util.Log.d("FaceEmbedder", "Detected Output Size: $outputSize")
        }
    }

    private fun loadModelFile(filename: String): MappedByteBuffer {
        val fileDescriptor: AssetFileDescriptor = assets.openFd(filename)
        val inputStream = FileInputStream(fileDescriptor.fileDescriptor)
        val fileChannel = inputStream.channel
        val startOffset = fileDescriptor.startOffset
        val declaredLength = fileDescriptor.declaredLength
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength)
    }

    private fun runInference(imageBytes: ByteArray): List<Float>? {
        if (tfliteInterpreter == null) initInterpreter()

        val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size) ?: return null
        
        // Resize bitmap to model input size
        val scaledBitmap = Bitmap.createScaledBitmap(bitmap, inputSize, inputSize, true)
        
        // Preprocess image to ByteBuffer (Float32)
        val inputBuffer = convertBitmapToByteBuffer(scaledBitmap)
        
        // Output buffer
        val outputBuffer = Array(1) { FloatArray(outputSize) }
        
        tfliteInterpreter?.run(inputBuffer, outputBuffer)
        
        return outputBuffer[0].toList()
    }

    private fun convertBitmapToByteBuffer(bitmap: Bitmap): ByteBuffer {
        val byteBuffer = ByteBuffer.allocateDirect(4 * 1 * inputSize * inputSize * 3)
        byteBuffer.order(ByteOrder.nativeOrder())
        
        val intValues = IntArray(inputSize * inputSize)
        bitmap.getPixels(intValues, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
        
        var pixel = 0
        for (i in 0 until inputSize) {
            for (j in 0 until inputSize) {
                val value = intValues[pixel++]
                
                // Normalization (Standard for many models: (value - 128) / 128.0)
                // Or sometimes value / 255.0. MobileFaceNet often uses (val - 128) / 128.
                byteBuffer.putFloat(((value shr 16 and 0xFF) - 128f) / 128f)
                byteBuffer.putFloat(((value shr 8 and 0xFF) - 128f) / 128f)
                byteBuffer.putFloat(((value and 0xFF) - 128f) / 128f)
            }
        }
        return byteBuffer
    }
}
