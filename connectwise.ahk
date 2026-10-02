#include <UIA>
SetTitleMatchMode 2

WinActivate("Manage: Time Entry")
DigIn := UIA.ElementFromHandle("Manage: Time Entry").WaitElement({Name:"From: NMGI Helpdesk", MatchMode:"StartsWith", Type:"DataItem"})
DigIn.FindElement({Type:"Edit"}).SetFocus()
Send("{Shift Down}{Tab}{Shift Up}{Space}")