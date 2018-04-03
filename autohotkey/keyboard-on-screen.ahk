; On-Screen Keyboard (requires XP/2k/NT) -- by Jon
;
; From https://www.autohotkey.com/docs/scripts/KeyboardOnScreen.ahk
;
; Modifications by Kyle George:
; -- add ESC and ` key support
; -- flatten keyboard
;
; http://www.autohotkey.com
; This script creates a mock keyboard at the bottom of your screen that shows
; the keys you are pressing in real time. I made it to help me to learn to
; touch-type (to get used to not looking at the keyboard).  The size of the
; on-screen keyboard can be customized at the top of the script. Also, you
; can double-click the tray icon to show or hide the keyboard.

;---- Configuration Section: Customize the size of the on-screen keyboard and
; other options here.

; Changing this font size will make the entire on-screen keyboard get
; larger or smaller:
k_FontSize = 10
k_FontName = Consolas ; This can be blank to use the system's default font.
k_FontStyle = Bold    ; Example of an alternative: Italic Underline

; Names for the tray menu items:
k_MenuItemHide = Hide on-screen &keyboard
k_MenuItemShow = Show on-screen &keyboard

; To have the keyboard appear on a monitor other than the primary, specify
; a number such as 2 for the following variable.  Leave it blank to use
; the primary:
k_Monitor = 

;---- End of configuration section.  Don't change anything below this point
; unless you want to alter the basic nature of the script.

;---- Alter the tray icon menu:
Menu, Tray, Add, %k_MenuItemHide%, k_ShowHide
Menu, Tray, Add, &Exit, k_MenuExit
Menu, Tray, Default, %k_MenuItemHide%
Menu, Tray, NoStandard

;---- Calculate object dimensions based on chosen font size:
k_KeyWidth = %k_FontSize%
k_KeyWidth *= 3
k_KeyWidthLarge = %k_FontSize%
k_KeyWidthLarge *= 4
k_KeyWidthXLarge = %k_FontSize%
k_KeyWidthXLarge *= 5
k_KeyHeight = %k_FontSize%
k_KeyHeight *= 2
k_KeyMargin = %k_FontSize%
k_KeyMargin /= 6

k_KeySize = w%k_KeyWidth% h%k_KeyHeight%
k_Position = x+%k_KeyMargin% %k_KeySize%

;---- Create a GUI window for the on-screen keyboard:
Gui, Font, s%k_FontSize% %k_FontStyle%, %k_FontName%
Gui, -Caption +E0x200 +ToolWindow
TransColor = F1ECED
Gui, Color, %TransColor%  ; This color will be made transparent later below.

;---- Add a button for each key.

Gui, Add, Button, %k_Position%, ESC ; Auto-width.
Gui, Add, Button, %k_Position% w%k_KeyWidthLarge%, Ctrl
Gui, Add, Button, %k_Position%, Alt ; Auto-width.
Gui, Add, Button, %k_Position%, Win ; Auto-width.
Gui, Add, Button, %k_Position% w%k_KeyWidthXLarge%, Space
Gui, Add, Button, %k_Position%, Tab ; Auto-width.
Gui, Add, Button, %k_Position%, Bk ; Auto-width.
Gui, Add, Button, %k_Position% w%k_KeyWidthXLarge%, Enter
Gui, Add, Button, %k_Position% w%k_KeyWidthXLarge%, Shift

Gui, Add, Button, %k_Position%, ``
Gui, Add, Button, %k_Position%, '
Gui, Add, Button, %k_Position%, -
Gui, Add, Button, %k_Position%, =
Gui, Add, Button, %k_Position%, [
Gui, Add, Button, %k_Position%, ]
Gui, Add, Button, %k_Position%, `,
Gui, Add, Button, %k_Position%, `;
Gui, Add, Button, %k_Position%, .
Gui, Add, Button, %k_Position%, \
Gui, Add, Button, %k_Position%, /

Gui, Add, Button, %k_Position%, 0
Gui, Add, Button, %k_Position%, 1
Gui, Add, Button, %k_Position%, 2
Gui, Add, Button, %k_Position%, 3
Gui, Add, Button, %k_Position%, 4
Gui, Add, Button, %k_Position%, 5
Gui, Add, Button, %k_Position%, 6
Gui, Add, Button, %k_Position%, 7
Gui, Add, Button, %k_Position%, 8
Gui, Add, Button, %k_Position%, 9

Gui, Add, Button, %k_Position%, A
Gui, Add, Button, %k_Position%, B
Gui, Add, Button, %k_Position%, C
Gui, Add, Button, %k_Position%, D
Gui, Add, Button, %k_Position%, E
Gui, Add, Button, %k_Position%, F
Gui, Add, Button, %k_Position%, G
Gui, Add, Button, %k_Position%, H
Gui, Add, Button, %k_Position%, I
Gui, Add, Button, %k_Position%, J
Gui, Add, Button, %k_Position%, K
Gui, Add, Button, %k_Position%, L
Gui, Add, Button, %k_Position%, M
Gui, Add, Button, %k_Position%, N
Gui, Add, Button, %k_Position%, O
Gui, Add, Button, %k_Position%, P
Gui, Add, Button, %k_Position%, Q
Gui, Add, Button, %k_Position%, R
Gui, Add, Button, %k_Position%, S
Gui, Add, Button, %k_Position%, T
Gui, Add, Button, %k_Position%, U
Gui, Add, Button, %k_Position%, V
Gui, Add, Button, %k_Position%, W
Gui, Add, Button, %k_Position%, X
Gui, Add, Button, %k_Position%, Y
Gui, Add, Button, %k_Position%, Z

;---- Show the window:
Gui, Show
k_IsVisible = y

WinGet, k_ID, ID, A   ; Get its window ID.
WinGetPos,,, k_WindowWidth, k_WindowHeight, A

;---- Position the keyboard at the bottom of the screen (taking into account
; the position of the taskbar):
SysGet, k_WorkArea, MonitorWorkArea, %k_Monitor%

; Calculate window's X-position:
k_WindowX = %k_WorkAreaRight%
k_WindowX -= %k_WorkAreaLeft%  ; Now k_WindowX contains the width of this monitor.
k_WindowX -= %k_WindowWidth%
k_WindowX /= 2  ; Calculate position to center it horizontally.
; The following is done in case the window will be on a non-primary monitor
; or if the taskbar is anchored on the left side of the screen:
k_WindowX += %k_WorkAreaLeft%

; Calculate window's Y-position:
k_WindowY = %k_WorkAreaBottom%
k_WindowY -= %k_WindowHeight%

WinMove, A,, %k_WindowX%, %k_WindowY%
WinSet, AlwaysOnTop, On, ahk_id %k_ID%
WinSet, TransColor, %TransColor% 220, ahk_id %k_ID%

;---- Set all keys as hotkeys. See www.asciitable.com
k_n = 1
k_ASCII = 45

Loop
{
	Transform, k_char, Chr, %k_ASCII%
	StringUpper, k_char, k_char
	if k_char not in <,>,^,~,�,`,
		Hotkey, ~*%k_char%, k_KeyPress
		; In the above, the asterisk prefix allows the key to be detected regardless
		; of whether the user is holding down modifier keys such as Control and Shift.
	if k_ASCII = 96
		break
	if k_ASCII = 93
		k_ASCII = 96
	else
		k_ASCII++
}

return ; End of auto-execute section.

;---- When a key is pressed by the user, click the corresponding button on-screen:

$ESC::
ControlClick, ESC, ahk_id %k_ID%, , LEFT, 1, D
KeyWait, ESC
ControlClick, ESC, ahk_id %k_ID%, , LEFT, 1, U
SendInput, {Escape}
return

~*Backspace::
ControlClick, Bk, ahk_id %k_ID%, , LEFT, 1, D
KeyWait, Backspace
ControlClick, Bk, ahk_id %k_ID%, , LEFT, 1, U
return

; LShift and RShift are used rather than "Shift" because when used as a hotkey,
; "Shift" would default to firing upon release of the key (in older AHK versions):
~*LShift::
~*RShift::
~*LCtrl::  ; Must use Ctrl not Control to match button names.
~*RCtrl::
~*LAlt::
~*RAlt::
~*LWin::
~*RWin::
StringTrimLeft, k_ThisHotkey, A_ThisHotkey, 3
ControlClick, %k_ThisHotkey%, ahk_id %k_ID%, , LEFT, 1, D
KeyWait, %k_ThisHotkey%
ControlClick, %k_ThisHotkey%, ahk_id %k_ID%, , LEFT, 1, U
return

~*,::
~*'::
~*Space::
~*Enter::
~*Tab::
k_KeyPress:
StringReplace, k_ThisHotkey, A_ThisHotkey, ~
StringReplace, k_ThisHotkey, k_ThisHotkey, *
SetTitleMatchMode, 3  ; Prevents the T and B keys from being confused with Tab and Backspace.
ControlClick, %k_ThisHotkey%, ahk_id %k_ID%, , LEFT, 1, D
KeyWait, %k_ThisHotkey%
ControlClick, %k_ThisHotkey%, ahk_id %k_ID%, , LEFT, 1, U
Return

k_ShowHide:
if k_IsVisible = y
{
	Gui, Cancel
	Menu, Tray, Rename, %k_MenuItemHide%, %k_MenuItemShow%
	k_IsVisible = n
}
else
{
	Gui, Show
	Menu, Tray, Rename, %k_MenuItemShow%, %k_MenuItemHide%
	k_IsVisible = y
}
return

GuiClose:
k_MenuExit:
ExitApp
