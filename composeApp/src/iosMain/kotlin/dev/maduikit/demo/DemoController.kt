package dev.maduikit.demo

import androidx.compose.ui.window.ComposeUIViewController
import platform.UIKit.UIViewController

fun makeDemoViewController(): UIViewController = ComposeUIViewController { DemoScreen() }
