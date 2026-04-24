package dev.jpj.nesd

import android.content.Intent
import android.hardware.input.InputManager
import android.os.Handler
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import dev.jpj.nesd.filesystem.FilesystemMethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity

class MainActivity : FlutterActivity(), GamepadsCompatibleActivity {
  private lateinit var filesystemMethodChannel: FilesystemMethodChannel
  private var keyEventHandler: ((KeyEvent) -> Boolean)? = null
  private var motionEventHandler: ((MotionEvent) -> Boolean)? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    filesystemMethodChannel =
      FilesystemMethodChannel(flutterEngine.dartExecutor.binaryMessenger, contentResolver, this)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, resultData: Intent?) {
    filesystemMethodChannel.onActivityResult(requestCode, resultCode, resultData)
  }

  override fun dispatchKeyEvent(keyEvent: KeyEvent): Boolean {
    if (keyEventHandler?.invoke(keyEvent) == true) {
      return true
    }

    return super.dispatchKeyEvent(keyEvent)
  }

  override fun dispatchGenericMotionEvent(motionEvent: MotionEvent): Boolean {
    if (motionEventHandler?.invoke(motionEvent) == true) {
      return true
    }

    return super.dispatchGenericMotionEvent(motionEvent)
  }

  override fun registerInputDeviceListener(
    listener: InputManager.InputDeviceListener,
    handler: Handler?,
  ) {
    val inputManager = getSystemService(INPUT_SERVICE) as InputManager
    inputManager.registerInputDeviceListener(listener, handler)
  }

  override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
    keyEventHandler = handler
  }

  override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
    motionEventHandler = handler
  }

  override fun isGamepadsInputDevice(device: InputDevice): Boolean {
    return device.sources and InputDevice.SOURCE_GAMEPAD ==
      InputDevice.SOURCE_GAMEPAD ||
      device.sources and InputDevice.SOURCE_JOYSTICK ==
        InputDevice.SOURCE_JOYSTICK &&
      device.keyboardType != InputDevice.KEYBOARD_TYPE_ALPHABETIC
  }
}
