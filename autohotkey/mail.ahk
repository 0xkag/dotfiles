#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir% ; Ensures a consistent starting directory.

; C-1 --> C-S-1 (for Outlook)
^1::
Send ^+1
return

; C-2 --> C-S-2 (for Outlook)
^2::
Send ^+2
return

; C-3 --> C-S-3 (for Outlook)
^3::
Send ^+3
return

; C-4 --> C-S-4 (for Outlook)
^4::
Send ^+4
return

; C-5 --> C-S-5 (for Outlook)
^5::
Send ^+5
return

; C-6 --> Alpine 
^6::
Send asINBOX-temp-
return

; C-0 --> Alpine select sequence
^0::
; Send {;}tf{ctrl down}r{ctrl up}
Send {;}tf^r{enter}
return

