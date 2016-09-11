; https://superuser.com/questions/406839/is-there-way-to-change-font-size-in-putty-using-the-wheel-in-mouse-or-contrl

ChangeFontSize(Direction="Down") {
    nIndex := 15
    WinGet, hWnd, ID, ahk_class PuTTY
    hSysMenu := DllCall("GetSystemMenu", "UInt", hWnd, "UInt", False)
    nID := DllCall("GetMenuItemID", "UInt", hSysMenu, "UInt", nIndex)
    PostMessage, 0x112, nID, 0, , ahk_id %hWnd%
    SendInput {Shift Down}{Tab}{Shift Up}a{LAlt Down}n{LAlt Up}{LAlt Down}s{LAlt Up}{%Direction%}{Enter}{LAlt Down}a{LAlt Up}
}

#IfWinActive ahk_class PuTTY
^=::
ChangeFontSize()
return

#IfWinActive ahk_class PuTTY
^-::
ChangeFontSize("Up")
return
