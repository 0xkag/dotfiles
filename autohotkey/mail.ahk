#NoEnv
#Warn

SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 2

ExcludeUrgent := False

FilterOutlook(filter, ItemName, ItemPos, MenuName)
{
	; open view menu in ribbon
	Send !v
	; open view settings dialog
	Send v
	; open filter dialog
	Send f

	; wait for filter dialog
	WinWait, Filter, OK, 5

	; get window text
	WinGetText, win_text, Filter

	If InStr(win_text, "SQL") {
		/*
		Existing filter is present if we start on SQL tab.  Edit criteria
		directly will be ON.  Clear criteria and edit criteria directly
		flag.
		*/
		; go to edit box
		Send !m
		; select all
		Send ^a
		; delete
		Send {del}
		; toggle edit criteria directly off
		Send !e
	} Else {
		; send shift-tab to go to SQL tab
		Send ^+{tab}
	}

	; at this point we're on the SQL tab with edit criteria directly off

	If StrLen(filter) > 0 {
		; toggle edit criteria directly on
		Send !e
		; go to edit box
		Send !m
		; send filter text
		Send {Blind}{Text}%filter%
	}

	; wait for filter dialog

	WinWait, Filter, OK, 5

	; go "click" OK

	if StrLen(filter) > 0 {
		; focus will be on filter edit box, need two tabs to get to OK
		Send {tab}{tab}{enter}
	} else {
		; focus will be on edit directly checkbox, need one tab
		Send {tab}{enter}
	}

	; close view settings dialog
	; TODO find a better way to click OK; ControlClick doesn't seem to work
	Send {tab}{tab}{tab}{tab}{tab}{tab}{tab}{enter}
	; go back to ribbon home
	Send !h
	; escape from tooltips that are displayed after ribbon hotkey
	Send {esc}{esc}
}

ToggleExcludeUrgent(ItemName, ItemPos, MenuName)
{
	global ExcludeUrgent
	Menu, %MenuName%, ToggleCheck, %ItemName%
	ExcludeUrgent := !ExcludeUrgent
}

GenCatFilter(Name)
{
	return "(""urn:schemas-microsoft-com:office:office#Keywords"" = '" . Name . "')"
}

GenFinalFilter(part)
{
	NotUrgent := "(not ""urn:schemas-microsoft-com:office:office#Keywords"" like '%urgent%')"

	global ExcludeUrgent

	if (ExcludeUrgent) {
		return part . " AND " . NotUrgent
	} else {
		return part
	}
}

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

; C-S-1 --> (for Outlook)
#IfWinActive, ahk_exe OUTLOOK.EXE
^+::

; Category SOMELABEL
; "urn:schemas-microsoft-com:office:office#Keywords" = 'SOMELABEL'
;
; Category empty
; "urn:schemas-microsoft-com:office:office#Keywords" IS NULL
;
; Importance High
; "urn:schemas:httpmail:importance" = 2
;
; From SOMEBODY
; ("http://schemas.microsoft.com/mapi/proptag/0x0065001f" CI_STARTSWITH 'SOMEBODY' OR "http://schemas.microsoft.com/mapi/proptag/0x0042001f" CI_STARTSWITH 'SOMEBODY')
;
; To SOMEBODY
; ("http://schemas.microsoft.com/mapi/proptag/0x0e04001f" CI_STARTSWITH 'SOMEBODY' OR "http://schemas.microsoft.com/mapi/proptag/0x0e03001f" CI_STARTSWITH 'SOMEBODY')
;
; Where I am the only person on the To line
; "http://schemas.microsoft.com/mapi/proptag/0x0e04001f" LIKE '%ME%'
;
; Where I am on the To line with other people
; ("http://schemas.microsoft.com/mapi/proptag/0x0e04001f" CI_STARTSWITH 'LAST' OR "http://schemas.microsoft.com/mapi/proptag/0x0e04001f" CI_STARTSWITH 'FIRST')
;
; Where I am on the CC line with other people
; ("http://schemas.microsoft.com/mapi/proptag/0x0e03001f" CI_STARTSWITH 'LAST' OR "http://schemas.microsoft.com/mapi/proptag/0x0e03001f" CI_STARTSWITH 'FIRST')
;
; Subject like SOMETHING
; "http://schemas.microsoft.com/mapi/proptag/0x0037001f" LIKE '%SOMETHING%'
;
; ---------
;
; filter := "some filter"
; FilterXYZ := Func("FilterOutlook").Bind(filter)
; FilterABC := Func("FilterOutlook").Bind(GenCatFilter("SOMECAT"))
; Filter123 := Func("FilterOutlook").Bind(GenFinalFilter(...))

#Include *i ..\_sites\current\autohotkey\outlook-filters.ahk

FilterClear := Func("FilterOutlook").Bind("")

Menu, MyMenu, Add, &0 Clear, % FilterClear
Menu, MyMenu, Show

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

