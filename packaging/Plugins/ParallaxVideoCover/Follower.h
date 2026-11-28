// Original Parallax code: keeps track of where one element (the video) is inside
// another window, through UI Automation. Everything that asks the other program
// runs on this object's own thread: such calls can take a second or more and must
// never stall Rainmeter.
#pragma once
#include <windows.h>
#include <uiautomation.h>
#include <condition_variable>
#include <mutex>
#include <string>
#include <thread>

class Follower {
public:
    // element is "class:<class name>" or "id:<automation id>".
    Follower(HWND window, const std::wstring& element)
        : window_(window), element_(element), thread_(&Follower::Run, this) {}

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

    // The element's rectangle in screen pixels, if it is on screen now.
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
        while (wanted) {
            if (!found) {
                IUIAutomationElement* root = nullptr;
                if (SUCCEEDED(automation->ElementFromHandle(window_, &root)) && root) {
                    if (FAILED(root->FindFirst(TreeScope_Descendants, wanted, &found))) found = nullptr;
                    root->Release();
                }
            }
            RECT rect{};
            bool known = false;
            if (found) {
                BOOL offscreen = TRUE;
                if (SUCCEEDED(found->get_CurrentBoundingRectangle(&rect)) &&
                    SUCCEEDED(found->get_CurrentIsOffscreen(&offscreen)) && !IsRectEmpty(&rect)) {
                    known = !offscreen;
                } else {
                    // Gone (another page, a new player): look for it again.
                    found->Release();
                    found = nullptr;
                }
            }
            Publish(known, rect);
            if (!Pause(found ? 200 : 1000)) break;
        }
        if (found) found->Release();
        if (wanted) wanted->Release();
        automation->Release();
    }

    const HWND window_;
    const std::wstring element_;
    std::mutex mutex_;
    std::condition_variable wake_;
    bool stop_ = false, known_ = false;
    RECT rect_{};
    std::thread thread_;   // last: it uses everything above
};
