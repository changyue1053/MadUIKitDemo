package dev.mad.synthetic.typography

import androidx.compose.ui.window.ComposeUIViewController
import platform.UIKit.UIViewController

fun fixtureViewController(): UIViewController = ComposeUIViewController { AtlasSearchCounter() }
