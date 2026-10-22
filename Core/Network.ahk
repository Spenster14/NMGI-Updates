#Requires AutoHotkey v2.0
; Core/Network.ahk - Fast UNC network reachability guards & host caching.
; Prevents multi-minute Windows SMB redirector timeouts when offline or off-network.

global HostCache := Map()

ClearHostCache() {
    global HostCache
    HostCache.Clear()
}

GetHostFromUNC(path) {
    if RegExMatch(path, "^\\\\([^\\]+)", &m)
        return m[1]
    return ""
}

IsHostReachable(host, port := 445, timeoutMs := 1000) {
    global HostCache
    if (host == "")
        return false

    hostKey := StrLower(host)
    if HostCache.Has(hostKey)
        return HostCache[hostKey]

    static WSAData := Buffer(400, 0)
    static init := DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", WSAData.Ptr)

    hints := Buffer(32 + A_PtrSize * 3, 0)
    NumPut("Int", 0, hints, 4)   ; AF_UNSPEC (support IPv4 and IPv6)
    NumPut("Int", 1, hints, 8)   ; SOCK_STREAM
    NumPut("Int", 6, hints, 12)  ; IPPROTO_TCP

    res := 0
    err := DllCall("ws2_32\getaddrinfo", "AStr", host, "AStr", String(port), "Ptr", hints.Ptr, "Ptr*", &res, "Int")
    if (err != 0 || res == 0) {
        HostCache[hostKey] := false
        return false
    }

    ai_family := NumGet(res, 4, "Int")
    ai_socktype := NumGet(res, 8, "Int")
    ai_protocol := NumGet(res, 12, "Int")
    ai_addrlen := NumGet(res, 16, "UPtr")
    ai_addr := NumGet(res, 16 + A_PtrSize * 2, "Ptr")

    sock := DllCall("ws2_32\socket", "Int", ai_family, "Int", ai_socktype, "Int", ai_protocol, "UPtr")
    if (sock == -1 || sock == 0xFFFFFFFF) {
        DllCall("ws2_32\freeaddrinfo", "Ptr", res)
        HostCache[hostKey] := false
        return false
    }

    mode := Buffer(4, 0)
    NumPut("UInt", 1, mode)
    DllCall("ws2_32\ioctlsocket", "UPtr", sock, "UInt", 0x8004667E, "Ptr", mode.Ptr)

    DllCall("ws2_32\connect", "UPtr", sock, "Ptr", ai_addr, "Int", ai_addrlen)
    DllCall("ws2_32\freeaddrinfo", "Ptr", res)

    write_fds := Buffer(8 + A_PtrSize, 0)
    NumPut("UInt", 1, write_fds, 0)
    NumPut("UPtr", sock, write_fds, A_PtrSize == 8 ? 8 : 4)

    tv := Buffer(8, 0)
    NumPut("Int", timeoutMs // 1000, tv, 0)
    NumPut("Int", (Mod(timeoutMs, 1000)) * 1000, tv, 4)

    sel := DllCall("ws2_32\select", "Int", 0, "Ptr", 0, "Ptr", write_fds.Ptr, "Ptr", 0, "Ptr", tv.Ptr, "Int")
    DllCall("ws2_32\closesocket", "UPtr", sock)

    reachable := (sel > 0)
    HostCache[hostKey] := reachable
    return reachable
}

SafeFileExist(path) {
    if (SubStr(path, 1, 2) == "\\") {
        host := GetHostFromUNC(path)
        if (host != "" && !IsHostReachable(host))
            return ""
    }
    return FileExist(path)
}
