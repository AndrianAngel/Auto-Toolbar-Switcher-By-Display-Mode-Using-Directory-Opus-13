' Script to automatically show/hide toolbars based on lister display mode
' Based on AutoFolderCommand.vbs by ThioJoe
' Modified to trigger toolbars on dual vertical/horizontal mode changes
' Enhanced to remember toolbar positions
'
' Version: 1.3 - Fixed position parameter handling

Option Explicit

Function OnInit(initData)
    initData.name = "Auto Toolbar By Display Mode"
    initData.version = "1.3"
    initData.desc = "Automatically show/hide toolbars when switching between dual vertical and dual horizontal display modes with position memory."
    initData.default_enable = true
    initData.min_version = "13.0"

    ' Configuration settings
    Dim config: Set config = initData.config
    Dim config_desc: Set config_desc = DOpus.Create.Map
    Dim config_groups: Set config_groups = DOpus.Create.Map

    ' Toolbar for Dual Vertical mode
    config.VerticalToolbar = "Toolbar V"
    config_desc("VerticalToolbar") = "Name of the toolbar to show in Dual Vertical mode. Leave empty to disable."
    config_groups("VerticalToolbar") = "1 - Toolbars"

    ' Toolbar for Dual Horizontal mode
    config.HorizontalToolbar = "Toolbar H"
    config_desc("HorizontalToolbar") = "Name of the toolbar to show in Dual Horizontal mode. Leave empty to disable."
    config_groups("HorizontalToolbar") = "1 - Toolbars"

    ' Position settings for Vertical toolbar
    config.VerticalToolbarState = DOpus.Create.Vector(1, "top", "bottom", "left", "right", "center", "float")
    config_desc("VerticalToolbarState") = "Position for Vertical toolbar"
    config_groups("VerticalToolbarState") = "2 - Vertical Toolbar Position"
    
    config.VerticalToolbarLine = 0
    config_desc("VerticalToolbarLine") = "Line position for Vertical toolbar (0 = default)"
    config_groups("VerticalToolbarLine") = "2 - Vertical Toolbar Position"

    ' Position settings for Horizontal toolbar
    config.HorizontalToolbarState = DOpus.Create.Vector(1, "top", "bottom", "left", "right", "center", "float")
    config_desc("HorizontalToolbarState") = "Position for Horizontal toolbar"
    config_groups("HorizontalToolbarState") = "3 - Horizontal Toolbar Position"
    
    config.HorizontalToolbarLine = 0
    config_desc("HorizontalToolbarLine") = "Line position for Horizontal toolbar (0 = default)"
    config_groups("HorizontalToolbarLine") = "3 - Horizontal Toolbar Position"

    ' Option to close toolbar when switching to single display mode
    config.CloseOnSingleMode = True
    config_desc("CloseOnSingleMode") = "Close the toolbar when switching to single display mode (not dual)"
    config_groups("CloseOnSingleMode") = "4 - Options"

    ' Debug logging option
    config_desc("DebugLevel") = "Set the level of debug output"
    config.DebugLevel = DOpus.Create.Vector(0, "0 - Off (Default)", "1 - Info", "2 - Verbose", "3 - Debug")
    config_groups("DebugLevel") = "4 - Options"

    initData.config_desc = config_desc
    initData.config_groups = config_groups
End Function

Sub DebugOutput(level, message)   
    If Script.config.DebugLevel >= level Then
        Dim levelString
        Select Case level
            Case 1
                levelString = "[Info]    | "
            Case 2
                levelString = "[Verbose] | "
            Case 3
                levelString = "[Debug]   | "
            Case Else
                levelString = "[Log]     | "
        End Select
        
        DOpus.Output levelString & message
    End If
End Sub

Function GetDisplayModeType(viewMode)
    ' Returns: "vertical", "horizontal", "single", or "unknown"
    ' ViewMode values: 0=single, 1=dual-vert, 2=dual-horiz, 3=tree
    
    Select Case viewMode
        Case 0
            GetDisplayModeType = "single"
        Case 1
            GetDisplayModeType = "vertical"
        Case 2
            GetDisplayModeType = "horizontal"
        Case 3
            GetDisplayModeType = "tree"
        Case Else
            GetDisplayModeType = "unknown"
    End Select
End Function

Function GetListerKey(lister)
    ' Create a unique key for this lister using its active tab
    If Not lister.ActiveTab Is Nothing Then
        GetListerKey = "PrevMode_" & CStr(lister.ActiveTab)
    Else
        GetListerKey = "PrevMode_Default"
    End If
End Function

Function GetStateTextFromIndex(stateIndex)
    ' Convert the Vector index to the actual state text
    Dim states: Set states = DOpus.Create.Vector("top", "bottom", "left", "right", "center", "float")
    
    ' Validate index is within bounds
    If stateIndex >= 0 And stateIndex < states.count Then
        GetStateTextFromIndex = states(stateIndex)
    Else
        GetStateTextFromIndex = "" ' Return empty if invalid
    End If
End Function

Sub ManageToolbarsForMode(lister, newMode, oldMode)
    Dim verticalToolbar, horizontalToolbar
    verticalToolbar = Trim(Script.config.VerticalToolbar)
    horizontalToolbar = Trim(Script.config.HorizontalToolbar)
    
    DebugOutput 2, "ManageToolbarsForMode - Old: " & oldMode & ", New: " & newMode
    
    ' Close old toolbar if needed
    If oldMode <> "" And oldMode <> newMode Then
        Dim oldToolbar
        oldToolbar = ""
        
        If oldMode = "vertical" And verticalToolbar <> "" Then
            oldToolbar = verticalToolbar
        ElseIf oldMode = "horizontal" And horizontalToolbar <> "" Then
            oldToolbar = horizontalToolbar
        End If
        
        If oldToolbar <> "" Then
            DebugOutput 1, "Closing toolbar: " & oldToolbar
            Dim closeCmd
            Set closeCmd = DOpus.Create.Command
            closeCmd.SetSourceTab lister.ActiveTab
            closeCmd.RunCommand "Toolbar """ & oldToolbar & """ CLOSE"
        End If
    End If
    
    ' Open new toolbar if applicable with position
    Dim newToolbar, toolbarStateText, toolbarLine
    newToolbar = ""
    toolbarStateText = ""
    toolbarLine = 0
    
    If newMode = "vertical" And verticalToolbar <> "" Then
        newToolbar = verticalToolbar
        ' Convert the index to actual text
        toolbarStateText = GetStateTextFromIndex(Script.config.VerticalToolbarState)
        toolbarLine = Script.config.VerticalToolbarLine
        DebugOutput 3, "Vertical toolbar position index: " & Script.config.VerticalToolbarState & " -> text: " & toolbarStateText
    ElseIf newMode = "horizontal" And horizontalToolbar <> "" Then
        newToolbar = horizontalToolbar
        ' Convert the index to actual text
        toolbarStateText = GetStateTextFromIndex(Script.config.HorizontalToolbarState)
        toolbarLine = Script.config.HorizontalToolbarLine
        DebugOutput 3, "Horizontal toolbar position index: " & Script.config.HorizontalToolbarState & " -> text: " & toolbarStateText
    End If
    
    ' Handle single mode
    If newMode = "single" And Script.config.CloseOnSingleMode Then
        DebugOutput 1, "Switched to single mode - closing any open toolbar"
        If verticalToolbar <> "" Then
            Dim closeCmdV
            Set closeCmdV = DOpus.Create.Command
            closeCmdV.SetSourceTab lister.ActiveTab
            closeCmdV.RunCommand "Toolbar """ & verticalToolbar & """ CLOSE"
        End If
        If horizontalToolbar <> "" And horizontalToolbar <> verticalToolbar Then
            Dim closeCmdH
            Set closeCmdH = DOpus.Create.Command
            closeCmdH.SetSourceTab lister.ActiveTab
            closeCmdH.RunCommand "Toolbar """ & horizontalToolbar & """ CLOSE"
        End If
        Exit Sub
    End If
    
    If newToolbar <> "" Then
        ' Build command with position parameters
        Dim toolbarCmd
        toolbarCmd = "Toolbar """ & newToolbar & """ TOGGLE LOCAL"
        
        ' Add STATE parameter if valid
        If toolbarStateText <> "" Then
            toolbarCmd = toolbarCmd & " STATE=" & toolbarStateText
            DebugOutput 3, "Adding STATE parameter: " & toolbarStateText
        End If
        
        ' Add LINE parameter if specified
        If toolbarLine > 0 Then
            toolbarCmd = toolbarCmd & " LINE=" & CStr(toolbarLine)
            DebugOutput 3, "Adding LINE parameter: " & CStr(toolbarLine)
        End If
        
        DebugOutput 1, "Opening toolbar with command: " & toolbarCmd
        
        Dim openCmd
        Set openCmd = DOpus.Create.Command
        openCmd.SetSourceTab lister.ActiveTab
        openCmd.RunCommand toolbarCmd
    End If
End Sub

Function OnListerUIChange(listerUIChangeData)
    If Script.config.DebugLevel >= 2 Then
        DOpus.Output "===================================== Lister UI Change ====================================="
    End If
    
    Dim lister
    Set lister = listerUIChangeData.lister
    
    ' Validate lister object before accessing properties
    If lister Is Nothing Then
        DebugOutput 3, "Lister object is Nothing, skipping"
        Exit Function
    End If
    
    ' Check if the lister is in a valid state
    On Error Resume Next
    Dim currentMode
    currentMode = GetDisplayModeType(lister.dual)
    If Err.Number <> 0 Then
        DebugOutput 2, "Cannot access lister.dual (lister may be closing), skipping. Error: " & Err.Description
        Err.Clear
        On Error Goto 0
        Exit Function
    End If
    On Error Goto 0
    
    DebugOutput 2, "Current display mode: " & currentMode & " (dual value: " & lister.dual & ")"
    
    ' Check if we have a stored previous mode for this lister
    Dim listerKey
    listerKey = GetListerKey(lister)
    
    Dim prevMode
    If Script.vars.Exists(listerKey) Then
        prevMode = Script.vars.Get(listerKey)
        DebugOutput 3, "Previous mode from cache: " & prevMode
    Else
        prevMode = ""
        DebugOutput 3, "No previous mode cached"
    End If
    
    ' If mode changed, manage toolbars
    If prevMode <> currentMode Then
        DebugOutput 1, "Display mode changed from """ & prevMode & """ to """ & currentMode & """"
        ManageToolbarsForMode lister, currentMode, prevMode
        
        ' Store current mode for next time
        Script.vars.Set listerKey, currentMode
    Else
        DebugOutput 3, "Display mode unchanged, no action needed"
    End If
End Function

Function OnActivateLister(activateListerData)
    If Script.config.DebugLevel >= 2 Then
        DOpus.Output "===================================== Lister Activated ====================================="
    End If
    
    Dim lister
    Set lister = activateListerData.lister
    
    ' Validate lister object
    If lister Is Nothing Then
        DebugOutput 3, "Lister object is Nothing, skipping"
        Exit Function
    End If
    
    ' Check and apply toolbar for current mode when lister is activated
    On Error Resume Next
    Dim currentMode
    currentMode = GetDisplayModeType(lister.dual)
    If Err.Number <> 0 Then
        DebugOutput 2, "Cannot access lister.dual (lister may be initializing), skipping. Error: " & Err.Description
        Err.Clear
        On Error Goto 0
        Exit Function
    End If
    On Error Goto 0
    
    DebugOutput 2, "Lister activated with display mode: " & currentMode
    
    ' Initialize the mode tracking for this lister if needed
    Dim listerKey
    listerKey = GetListerKey(lister)
    
    If Not Script.vars.Exists(listerKey) Then
        DebugOutput 3, "Initializing mode tracking for this lister"
        Script.vars.Set listerKey, currentMode
        
        ' Apply toolbar for current mode
        ManageToolbarsForMode lister, currentMode, ""
    End If
End Function