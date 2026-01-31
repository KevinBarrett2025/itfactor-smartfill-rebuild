// MODULAR EDITOR CONFIGURATION
// This file enables the modular editor system

// Enable modular editor (comment out to disable)
// The modular system provides:
// - Landscape Video: Full toolset (trim, crop, SmartFill)  
// - Portrait Video: SmartFill primary, auto-switch to landscape when complete
// - Photo: Crop only, no video controls
//
// The system preserves all existing functionality and can be safely disabled

// Note: In a real project, this would be set in Build Settings > Other Swift Flags: -DSTS_MODULAR_EDITOR
// For now, we'll use a simple boolean flag

let STS_MODULAR_EDITOR_ENABLED = true
let STS_ENTERPRISE_EDITOR_ENABLED = true
let STS_EDITORCORE_SSOT_ENABLED = true
let STS_SEEKSCHEDULER_ENABLED = true
