package com.example.superscanserver

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo

class InputAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        Log.d("InputAccessibilityService", "Service connected")
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_VIEW_FOCUSED or AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        Log.d("InputAccessibilityService", "Received accessibility event: ${event.eventType}")
    }

    override fun onInterrupt() {
        Log.d("InputAccessibilityService", "Service interrupted")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("InputAccessibilityService", "onStartCommand called")
        if (intent != null) {
            val text = intent.getStringExtra("text")
            if (text != null) {
                Log.d("InputAccessibilityService", "Attempting to input text: $text")
                inputText(text)
            } else {
                Log.e("InputAccessibilityService", "Received null text in intent")
            }
        } else {
            Log.e("InputAccessibilityService", "Received null intent")
        }
        return START_NOT_STICKY
    }

    private fun inputText(text: String) {
        val rootInActiveWindow = rootInActiveWindow
        if (rootInActiveWindow == null) {
            Log.e("InputAccessibilityService", "rootInActiveWindow is null")
            return
        }

        val focusedNode = findFocusedNode(rootInActiveWindow)
        if (focusedNode != null) {
            val bundle = Bundle()
            bundle.putString(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            val result = focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, bundle)
            Log.d("InputAccessibilityService", "Text input action performed, result: $result")
        } else {
            Log.e("InputAccessibilityService", "No focused editable node found")
        }
    }

    private fun findFocusedNode(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (root.isFocused && root.isEditable) {
            return root
        }
        for (i in 0 until root.childCount) {
            val child = root.getChild(i) ?: continue
            val focusedChild = findFocusedNode(child)
            if (focusedChild != null) {
                return focusedChild
            }
        }
        return null
    }
}