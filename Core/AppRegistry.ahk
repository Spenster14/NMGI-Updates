#Requires AutoHotkey v2.0
; Core/AppRegistry.ahk - Declarative application definitions, category rules, and sorting.
; Extracted from NMGIUpdates.ahk (Milestone 2, Step 2.1).

global Apps := [
    { Name: "Quickbooks Enterprise 22", Label: "QB Enterprise 2022", fn: (*) => QB("22 Enterprise"), pathFn: (*) => GetQBPath("22 Enterprise") },
    { Name: "Quickbooks Enterprise 23", Label: "QB Enterprise 2023", fn: (*) => QB("23 Enterprise"), pathFn: (*) => GetQBPath("23 Enterprise") },
    { Name: "Quickbooks Enterprise 24", Label: "QB Enterprise 2024", fn: (*) => QB("24 Enterprise"), pathFn: (*) => GetQBPath("24 Enterprise") },
    { Name: "Quickbooks Premier 22",    Label: "QB Premier 2022",    fn: (*) => QB("22 Premier"),    pathFn: (*) => GetQBPath("22 Premier") },
    { Name: "Quickbooks Premier 23",    Label: "QB Premier 2023",    fn: (*) => QB("23 Premier"),    pathFn: (*) => GetQBPath("23 Premier") },
    { Name: "Quickbooks Premier 24",    Label: "QB Premier 2024",    fn: (*) => QB("24 Premier"),    pathFn: (*) => GetQBPath("24 Premier") },
    { Name: "Ultratax 23",              Label: "UltraTax 2023",      fn: (*) => UT("23"),            pathFn: (*) => GetUTPath("23") },
    { Name: "Ultratax 24",              Label: "UltraTax 2024",      fn: (*) => UT("24"),            pathFn: (*) => GetUTPath("24") },
    { Name: "Ultratax 25",              Label: "UltraTax 2025",      fn: (*) => UT("25"),            pathFn: (*) => GetUTPath("25") },
    { Name: "FileCabinet",              Label: "FileCabinet",        fn: (*) => FileCabinet(),       pathFn: (*) => GetFileCabinetPath() },
    { Name: "FixedAssetsCS",            Label: "Fixed Assets CS",    fn: (*) => FixedAssets(),       pathFn: (*) => GetFixedAssetsPath() },
    { Name: "AccountingCS",             Label: "Accounting CS",      fn: (*) => AccountingCS(),      pathFn: (*) => GetAccountingCSPath() },
    { Name: "Lacerte 22",               Label: "Lacerte 2022",       fn: (*) => Lacerte("22"),       pathFn: (*) => GetLacertePath("22") },
    { Name: "Lacerte 23",               Label: "Lacerte 2023",       fn: (*) => Lacerte("23"),       pathFn: (*) => GetLacertePath("23") },
    { Name: "Lacerte 24",               Label: "Lacerte 2024",       fn: (*) => Lacerte("24"),       pathFn: (*) => GetLacertePath("24") },
    { Name: "Adobe Acrobat",            Label: "Adobe Acrobat",      fn: (*) => Adobe(),             pathFn: (*) => GetAdobePath() },
    { Name: "Chrome",                   Label: "Chrome",             fn: (*) => Chrome(),            pathFn: (*) => GetChromePath() },
    { Name: "Edge",                     Label: "Edge",               fn: (*) => Edge(),              pathFn: (*) => GetEdgePath() },
    { Name: "Firefox",                  Label: "Firefox",            fn: (*) => Firefox(),           pathFn: (*) => GetFirefoxPath() }
]

GetAppCategory(appName) {
    if InStr(appName, "UltraTax") || InStr(appName, "FileCabinet") || InStr(appName, "Fixed Assets") || InStr(appName, "Accounting")
        return 1
    if InStr(appName, "QB") || InStr(appName, "Quickbooks")
        return 2
    if InStr(appName, "Chrome") || InStr(appName, "Edge") || InStr(appName, "Firefox")
        return 4
    return 3
}

SortApps(appList) {
    sorted := []
    for app in appList
        sorted.Push(app)

    loop sorted.Length {
        i := A_Index
        loop sorted.Length - i {
            app1 := sorted[A_Index]
            app2 := sorted[A_Index + 1]
            cat1 := GetAppCategory(app1.Label)
            cat2 := GetAppCategory(app2.Label)

            swap := false
            if (cat1 > cat2) {
                swap := true
            } else if (cat1 == cat2) {
                if (StrCompare(app1.Label, app2.Label) > 0)
                    swap := true
            }

            if (swap) {
                temp := sorted[A_Index]
                sorted[A_Index] := sorted[A_Index + 1]
                sorted[A_Index + 1] := temp
            }
        }
    }
    return sorted
}
