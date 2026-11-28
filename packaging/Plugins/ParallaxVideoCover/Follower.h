// Original Parallax code: keeps track of where one element (the video) is inside
// another window, through UI Automation. Everything that asks the other program
// runs on this object's own thread: such calls can take a second or more and must
// never stall Rainmeter.
#pragma once
#include <windows.h>
#include <uiautomation.h>
#include <climits>
#include "PageTitle.h"
#include <condition_variable>
#include <mutex>
#include <string>
#include <thread>

class Follower {
public:
    // element is "class:<class name>" or "id:<automation id>". With a mark, the
    // window is only looked into while its title carries it (PageTitle.h).
    Follower(HWND window, const std::wstring& element, const std::wstring& mark)
        : window_(window), element_(element), mark_(mark), thread_(&Follower::Run, this) {}

    ~Follower() {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            stop_ = true;
        }
        wake_.notify_all();
        thread_.join();
    }

    Follower(const Follower&) = delete;
    Follower& operator=(const Follower&) = delete;

    // The element's rectangle in the window's own client pixels, if it is on
    // screen now. Kept relative to the window, so that dragging the window does
    // not move what is cut out.
    bool Read(RECT* out) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!known_) return false;
        *out = rect_;
        return true;
    }

private:
    // False once asked to stop.
    bool Pause(DWORD milliseconds) {
        std::unique_lock<std::mutex> lock(mutex_);
        return !wake_.wait_for(lock, std::chrono::milliseconds(milliseconds), [this] { return stop_; });
    }

    void Publish(bool known, const RECT& rect) {
        std::lock_guard<std::mutex> lock(mutex_);
        known_ = known;
        rect_ = rect;
    }

    void Run() {
        // Real pixels, whatever Rainmeter's own mode is.
        SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
        if (FAILED(CoInitializeEx(nullptr, COINIT_MULTITHREADED))) return;
        Follow();
        CoUninitialize();
    }

    void Follow() {
        IUIAutomation2* automation = nullptr;
        if (FAILED(CoCreateInstance(__uuidof(CUIAutomation8), nullptr, CLSCTX_INPROC_SERVER, __uuidof(IUIAutomation2),
                                    reinterpret_cast<void**>(&automation))))
            return;
        // A hung browser must not hold the thread (and so a skin refresh) for long.
        automation->put_ConnectionTimeout(2000);
        automation->put_TransactionTimeout(2000);

        const bool byId = element_.rfind(L"id:", 0) == 0;
        const std::wstring name = element_.substr(element_.find(L':') + 1);
        VARIANT value;
        VariantInit(&value);
        value.vt = VT_BSTR;
        value.bstrVal = SysAllocString(name.c_str());
        IUIAutomationCondition* wanted = nullptr;
        automation->CreatePropertyCondition(byId ? UIA_AutomationIdPropertyId : UIA_ClassNamePropertyId, value, &wanted);
        VariantClear(&value);

        IUIAutomationElement* found = nullptr;
        int misses = 0;
        while (wanted) {
            // Another tab is in front: that page is not ours to read.
            if (!TitleAllows(window_, mark_)) {
                if (found) { found->Release(); found = nullptr; }
                Publish(false, RECT{});
                if (!Pause(300)) break;
                continue;
            }
            if (!found) {
                IUIAutomationElement* root = nullptr;
                if (SUCCEEDED(automation->ElementFromHandle(window_, &root)) && root) {
                    if (FAILED(root->FindFirst(TreeScope_Descendants, wanted, &found))) found = nullptr;
                    root->Release();
                }
            }
            RECT rect{};
            bool known = false;
            // Where the window is, before and after asking. Chrome reports screen
            // positions, and they trail behind a window that is being moved.
            POINT before{0, 0}, after{0, 0};
            ClientToScreen(window_, &before);
            if (found) {
                BOOL offscreen = TRUE;
                if (SUCCEEDED(found->get_CurrentBoundingRectangle(&rect)) &&
                    SUCCEEDED(found->get_CurrentIsOffscreen(&offscreen)) && !IsRectEmpty(&rect)) {
                    known = !offscreen;
                }
                // Hidden (another YouTube tab in front) or gone (another page, a
                // new player): look for the one showing.
                if (!known) {
                    found->Release();
                    found = nullptr;
                }
            }
            ClientToScreen(window_, &after);
            const bool moving = before.x != after.x || before.y != after.y || before.x != last_.x || before.y != last_.y;
            last_ = after;
            // While it moves, what was last read at rest still holds.
            if (!moving) {
                OffsetRect(&rect, -before.x, -before.y);
                Publish(known, rect);
            }
            // Walking a large page costs: look less often while there is no video.
            misses = found ? 0 : misses + 1;
            if (!Pause(found ? 200 : (misses > 5 ? 3000 : 1000))) break;
        }
        if (found) found->Release();
        if (wanted) wanted->Release();
        automation->Release();
    }

    const HWND window_;
    const std::wstring element_, mark_;
    std::mutex mutex_;
    std::condition_variable wake_;
    bool stop_ = false, known_ = false;
    RECT rect_{};
    POINT last_{LONG_MIN, LONG_MIN};   // follower thread only
    std::thread thread_;   // last: it uses everything above
};
