// Parallax's experimental video cover plugin (original code): draws another window on this skin's own window
// as a DWM thumbnail, so it moves, layers and hides with the skin. The source is
// the browser's picture-in-picture window; else the video inside the YouTube web
// app's window; else the video in an ordinary browser window while a YouTube
// page is the tab in front. The video's place is followed through UI
// Automation. Built by Build.ps1 with MSVC.
//
// Measure options (with DynamicVariables=1): Show; X, Y, Size and Radius of the
// cover (skin pixels); Zoom (1 fills the square); AllowPlayer with Player (when
// AllowPlayer is given, nothing is drawn unless Player equals it); SourceTitle
// SourceElement and SourceMark (tests only: a stand-in window, the element in it
// to cut out, and text its title must carry for anything to be drawn). The measure's value is 1 while something is drawn.
//
// The few Rainmeter functions it needs are looked up in the running Rainmeter.dll,
// so the plugin SDK's header and library are not needed.
#include <windows.h>
#include <dwmapi.h>
#include <memory>
#include <propkey.h>
#include <propsys.h>
#include <shellapi.h>
#include <string>
#include "Follower.h"

namespace {

// Chrome's id for the installed YouTube web app, and the page element YouTube
// plays video in.
const wchar_t* const kAppId = L"_crx_agimnkijcamfeangaknmldooml";
const wchar_t* const kVideoElement = L"class:video-stream html5-main-video";

typedef LPCWSTR(__stdcall* ReadStringFn)(void*, LPCWSTR, LPCWSTR, BOOL);
typedef double(__stdcall* ReadFormulaFn)(void*, LPCWSTR, double);
typedef void*(__stdcall* GetFn)(void*, int);
const int kSkinWindowHandle = 4;   // RmGetType RMG_SKINWINDOWHANDLE

ReadStringFn ReadString;
ReadFormulaFn ReadFormula;
GetFn Get;

bool LoadRainmeter() {
    HMODULE module = GetModuleHandleW(L"Rainmeter.dll");
    if (!module) return false;
    ReadString = reinterpret_cast<ReadStringFn>(GetProcAddress(module, "RmReadString"));
    ReadFormula = reinterpret_cast<ReadFormulaFn>(GetProcAddress(module, "RmReadFormula"));
    Get = reinterpret_cast<GetFn>(GetProcAddress(module, "RmGet"));
    return ReadString && ReadFormula && Get;
}

struct Measure {
    HWND skin = nullptr;
    HWND source = nullptr;
    HTHUMBNAIL thumb = nullptr;
    bool show = false, zoom = false;
    int x = 0, y = 0, size = 0, radius = 0;
    std::wstring sourceTitle, sourceElement, sourceMark;
    // What the source's title must carry, if its content can change under it.
    std::wstring mark;
    RECT dest{}, crop{};
    // Set while the source is a window that only part of is wanted from.
    std::unique_ptr<Follower> follower;
    bool wholeWindow = true;
    ULONGLONG looked = 0;
};

// Looks at other windows in their real pixels, whatever Rainmeter's own mode.
struct PixelScope {
    DPI_AWARENESS_CONTEXT before;
    PixelScope() : before(SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)) {}
    ~PixelScope() { if (before) SetThreadDpiAwarenessContext(before); }
};

bool IsBrowser(HWND window) {
    DWORD id = 0;
    GetWindowThreadProcessId(window, &id);
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, id);
    if (!process) return false;
    wchar_t path[MAX_PATH];
    DWORD length = MAX_PATH;
    bool found = false;
    if (QueryFullProcessImageNameW(process, 0, path, &length)) {
        const wchar_t* name = wcsrchr(path, L'\\');
        name = name ? name + 1 : path;
        for (const wchar_t* browser : {L"chrome.exe", L"msedge.exe", L"brave.exe", L"firefox.exe"})
            found = found || _wcsicmp(name, browser) == 0;
    }
    CloseHandle(process);
    return found;
}

// Is this one of the YouTube web app's own windows (no tabs, only YouTube)?
bool IsYouTubeApp(HWND window) {
    IPropertyStore* store = nullptr;
    if (FAILED(SHGetPropertyStoreForWindow(window, IID_PPV_ARGS(&store)))) return false;
    PROPVARIANT id;
    PropVariantInit(&id);
    bool found = SUCCEEDED(store->GetValue(PKEY_AppUserModel_ID, &id)) && id.vt == VT_LPWSTR && wcsstr(id.pwszVal, kAppId);
    PropVariantClear(&id);
    store->Release();
    return found;
}

enum class Kind { PictureInPicture, App, Tab };

struct Search { const std::wstring* wanted; Kind kind; HWND found; };

BOOL CALLBACK Match(HWND window, LPARAM parameter) {
    Search* search = reinterpret_cast<Search*>(parameter);
    if (!IsWindowVisible(window)) return TRUE;
    wchar_t title[256];
    int length = GetWindowTextW(window, title, 256);
    if (length <= 0) return TRUE;
    if (!search->wanted->empty()) {
        if (_wcsicmp(title, search->wanted->c_str()) != 0) return TRUE;
    } else {
        // "Picture in picture" or "Picture-in-picture" (English browsers).
        for (int i = 0; i < length; ++i) if (title[i] == L'-') title[i] = L' ';
        const bool little = _wcsicmp(title, L"picture in picture") == 0;
        if (search->kind == Kind::PictureInPicture) {
            if (!little || !IsBrowser(window)) return TRUE;
        } else if (little || IsIconic(window) || !IsBrowser(window)) {
            return TRUE;
        } else if (search->kind == Kind::App ? !IsYouTubeApp(window)
                                             : IsYouTubeApp(window) || !TitleAllows(window, kWatchPage)) {
            return TRUE;
        }
    }
    search->found = window;
    return FALSE;
}

void Drop(Measure* m) {
    if (m->thumb) DwmUnregisterThumbnail(m->thumb);
    m->thumb = nullptr;
    SetRectEmpty(&m->dest);
    SetRectEmpty(&m->crop);
}

void Forget(Measure* m) {
    Drop(m);
    m->follower.reset();
    m->source = nullptr;
}

HWND Find(const std::wstring& title, Kind kind) {
    Search search{&title, kind, nullptr};
    EnumWindows(Match, reinterpret_cast<LPARAM>(&search));
    return search.found;
}

// Chooses the window to draw from, looking at most once a second: Update may run
// many times a second. Picture-in-picture, when open, comes before the app.
void Choose(Measure* m) {
    if (m->source && !(IsWindow(m->source) && IsWindowVisible(m->source))) Forget(m);
    const ULONGLONG now = GetTickCount64();
    if (m->looked && now - m->looked < 1000) return;
    m->looked = now;
    HWND window = nullptr;
    bool whole = true;
    std::wstring element, mark;
    if (!m->sourceTitle.empty()) {
        window = Find(m->sourceTitle, Kind::PictureInPicture);
        element = m->sourceElement;
        mark = m->sourceMark;
        whole = element.empty();
    } else if ((window = Find(m->sourceTitle, Kind::PictureInPicture)) == nullptr) {
        // Stay with the window already followed rather than hop between two. An
        // ordinary window whose tab changed is kept (and shows nothing) unless
        // another has a YouTube page in front.
        const bool following = !m->wholeWindow && m->source && !IsIconic(m->source);
        if (following && TitleAllows(m->source, m->mark)) return;
        window = Find(m->sourceTitle, Kind::App);
        if (window) {
            whole = false;
            element = kVideoElement;
        } else if ((window = Find(m->sourceTitle, Kind::Tab)) != nullptr) {
            whole = false;
            element = kVideoElement;
            mark = kWatchPage;
        } else if (following && !m->mark.empty()) {
            return;
        }
    }
    if (window == m->source) return;
    Forget(m);
    m->source = window;
    m->wholeWindow = whole;
    m->mark = mark;
    if (window && !whole) m->follower.reset(new Follower(window, element, mark));
}

// The part of the source window to draw, in its client pixels.
bool Wanted(Measure* m, const RECT& client, RECT* part) {
    if (m->wholeWindow) { *part = client; return true; }
    RECT video{};
    if (!m->follower || IsIconic(m->source) || !m->follower->Read(&video)) return false;
    if (!IntersectRect(part, &video, &client)) return false;
    // Mostly scrolled or pushed out of the window: better nothing than a sliver.
    const long long seen = static_cast<long long>(part->right - part->left) * (part->bottom - part->top);
    const long long all = static_cast<long long>(video.right - video.left) * (video.bottom - video.top);
    return seen * 2 >= all;
}

bool Apply(Measure* m) {
    if (!m->show || m->size < 64 || !m->skin) { Forget(m); m->looked = 0; return false; }
    PixelScope pixels;
    Choose(m);
    if (!m->source) { Drop(m); return false; }

    RECT client{}, part{};
    GetClientRect(m->source, &client);
    // Checked on every update, so another tab is not shown while the follower
    // thread has yet to notice.
    if (!m->wholeWindow && !TitleAllows(m->source, m->mark)) { Drop(m); return false; }
    if (client.right <= 0 || client.bottom <= 0 || !Wanted(m, client, &part)) { Drop(m); return false; }
    const int cw = part.right - part.left, ch = part.bottom - part.top;
    if (!m->thumb && FAILED(DwmRegisterThumbnail(m->skin, m->source, &m->thumb))) { m->thumb = nullptr; return false; }

    // In from the cover's edge so its frame stays visible. A zoomed picture has
    // square corners, so it comes in far enough for them to stay inside the
    // rounded ones (radius * (1 - 1/sqrt 2), rounded up).
    int inset = 1;
    if (m->zoom && (m->radius * 3 + 9) / 10 > inset) inset = (m->radius * 3 + 9) / 10;
    const int inner = m->size - 2 * inset;
    RECT crop = part;
    int w = inner, h = MulDiv(inner, ch, cw);
    if (h > inner) { h = inner; w = MulDiv(inner, cw, ch); }
    if (m->zoom) {
        const int edge = cw < ch ? cw : ch;
        crop = {part.left + (cw - edge) / 2, part.top + (ch - edge) / 2, part.left + (cw + edge) / 2, part.top + (ch + edge) / 2};
        w = h = inner;
    }
    const int left = m->x + (m->size - w) / 2, top = m->y + (m->size - h) / 2;
    const RECT dest{left, top, left + w, top + h};
    if (!EqualRect(&dest, &m->dest) || !EqualRect(&crop, &m->crop)) {
        DWM_THUMBNAIL_PROPERTIES p{};
        p.dwFlags = DWM_TNP_RECTDESTINATION | DWM_TNP_RECTSOURCE | DWM_TNP_OPACITY | DWM_TNP_VISIBLE | DWM_TNP_SOURCECLIENTAREAONLY;
        p.rcDestination = dest;
        p.rcSource = crop;
        p.opacity = 255;
        p.fVisible = TRUE;
        p.fSourceClientAreaOnly = TRUE;
        if (FAILED(DwmUpdateThumbnailProperties(m->thumb, &p))) { Drop(m); return false; }
        m->dest = dest;
        m->crop = crop;
    }
    return true;
}

}  // namespace

extern "C" __declspec(dllexport) void Initialize(void** data, void* rm) {
    Measure* m = new Measure();
    *data = m;
    if (LoadRainmeter()) m->skin = static_cast<HWND>(Get(rm, kSkinWindowHandle));
}

extern "C" __declspec(dllexport) void Reload(void* data, void* rm, double* maxValue) {
    Measure* m = static_cast<Measure*>(data);
    if (!ReadFormula) return;
    m->show = ReadFormula(rm, L"Show", 0) == 1;
    const std::wstring allowed = ReadString(rm, L"AllowPlayer", L"", TRUE);
    if (!allowed.empty() && allowed != ReadString(rm, L"Player", L"", TRUE)) m->show = false;
    m->radius = static_cast<int>(ReadFormula(rm, L"Radius", 0) + 0.5);
    m->zoom = ReadFormula(rm, L"Zoom", 0) == 1;
    m->x = static_cast<int>(ReadFormula(rm, L"X", 0) + 0.5);
    m->y = static_cast<int>(ReadFormula(rm, L"Y", 0) + 0.5);
    m->size = static_cast<int>(ReadFormula(rm, L"Size", 0) + 0.5);
    const std::wstring title = ReadString(rm, L"SourceTitle", L"", TRUE);
    const std::wstring element = ReadString(rm, L"SourceElement", L"", TRUE);
    const std::wstring mark = ReadString(rm, L"SourceMark", L"", TRUE);
    if (title != m->sourceTitle || element != m->sourceElement || mark != m->sourceMark) {
        Forget(m);
        m->looked = 0;
        m->sourceTitle = title;
        m->sourceElement = element;
        m->sourceMark = mark;
    }
    if (maxValue) *maxValue = 1;
}

extern "C" __declspec(dllexport) double Update(void* data) {
    return Apply(static_cast<Measure*>(data)) ? 1.0 : 0.0;
}

extern "C" __declspec(dllexport) void Finalize(void* data) {
    Measure* m = static_cast<Measure*>(data);
    Forget(m);
    delete m;
}
