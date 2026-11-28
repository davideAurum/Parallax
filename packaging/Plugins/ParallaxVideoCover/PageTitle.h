// Original Parallax code: may this browser window be looked into? An ordinary
// window shows whatever tab is in front, so its title has to say that is a
// YouTube page with a name ("<video> - YouTube - Google Chrome"; Edge writes
// "<video> - YouTube and 2 more pages - ...").
#pragma once
#include <windows.h>
#include <string>

// The mark meaning "a named YouTube page"; any other mark must simply appear.
const wchar_t* const kWatchPage = L"youtube-watch";

inline bool TitleAllows(HWND window, const std::wstring& mark) {
    if (mark.empty()) return true;
    wchar_t buffer[512];
    const int length = GetWindowTextW(window, buffer, 512);
    const std::wstring title(buffer, length > 0 ? length : 0);
    if (mark != kWatchPage) return title.find(mark) != std::wstring::npos;
    return title.find(L" - YouTube - ") != std::wstring::npos || title.find(L" - YouTube and ") != std::wstring::npos;
}
