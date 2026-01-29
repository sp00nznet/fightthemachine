// Fight the Machine - Win32 Native Client
// Embeds WebView2 to display noVNC interface for containerized psDoom-ng

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <shellapi.h>
#include <shlwapi.h>
#include <wrl.h>
#include <wil/com.h>
#include <WebView2.h>
#include <WebView2EnvironmentOptions.h>
#include <string>
#include <thread>
#include <atomic>
#include <chrono>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "shell32.lib")

using namespace Microsoft::WRL;

// Global variables
static HWND g_hWnd = nullptr;
static ComPtr<ICoreWebView2Controller> g_webviewController;
static ComPtr<ICoreWebView2> g_webview;
static std::atomic<bool> g_containerRunning(false);
static std::atomic<bool> g_shutdownRequested(false);
static HANDLE g_dockerThread = nullptr;

// Configuration
const wchar_t* APP_TITLE = L"Fight the Machine";
const wchar_t* NOVNC_URL = L"http://localhost:6080/vnc.html?autoconnect=true&resize=scale";
const int WINDOW_WIDTH = 1024;
const int WINDOW_HEIGHT = 768;
const int STARTUP_TIMEOUT_MS = 60000;
const int HEALTH_CHECK_INTERVAL_MS = 2000;

// Forward declarations
LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
bool InitWebView(HWND hwnd);
bool StartDockerContainer();
bool StopDockerContainer();
bool IsDockerRunning();
bool IsContainerHealthy();
void ShowError(const wchar_t* message);
void ShowStatus(const wchar_t* status);
std::wstring GetExecutableDirectory();

// Docker management thread
DWORD WINAPI DockerManagerThread(LPVOID lpParam) {
    // Start the container
    if (!StartDockerContainer()) {
        PostMessage(g_hWnd, WM_USER + 1, 0, 0); // Signal startup failure
        return 1;
    }

    // Wait for container to become healthy
    auto startTime = std::chrono::steady_clock::now();
    while (!g_shutdownRequested) {
        if (IsContainerHealthy()) {
            g_containerRunning = true;
            PostMessage(g_hWnd, WM_USER + 2, 0, 0); // Signal ready to load URL
            break;
        }

        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - startTime).count();

        if (elapsed > STARTUP_TIMEOUT_MS) {
            PostMessage(g_hWnd, WM_USER + 1, 0, 0); // Signal timeout
            return 1;
        }

        Sleep(500);
    }

    // Monitor container health
    while (!g_shutdownRequested && g_containerRunning) {
        Sleep(HEALTH_CHECK_INTERVAL_MS);
        if (!IsContainerHealthy()) {
            g_containerRunning = false;
            PostMessage(g_hWnd, WM_USER + 3, 0, 0); // Signal container stopped
        }
    }

    return 0;
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR pCmdLine, int nCmdShow) {
    // Initialize COM
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) {
        ShowError(L"Failed to initialize COM");
        return 1;
    }

    // Check if Docker is available
    if (!IsDockerRunning()) {
        MessageBoxW(nullptr,
            L"Docker Desktop is not running.\n\n"
            L"Please install and start Docker Desktop, then run this application again.\n\n"
            L"Download: https://www.docker.com/products/docker-desktop/",
            APP_TITLE, MB_OK | MB_ICONERROR);
        CoUninitialize();
        return 1;
    }

    // Register window class
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(WNDCLASSEXW);
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = hInstance;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = L"FightTheMachineClass";
    wc.hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(1)); // Load icon if available

    if (!RegisterClassExW(&wc)) {
        ShowError(L"Failed to register window class");
        CoUninitialize();
        return 1;
    }

    // Calculate centered window position
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    int posX = (screenWidth - WINDOW_WIDTH) / 2;
    int posY = (screenHeight - WINDOW_HEIGHT) / 2;

    // Create main window
    g_hWnd = CreateWindowExW(
        0,
        L"FightTheMachineClass",
        APP_TITLE,
        WS_OVERLAPPEDWINDOW,
        posX, posY, WINDOW_WIDTH, WINDOW_HEIGHT,
        nullptr, nullptr, hInstance, nullptr
    );

    if (!g_hWnd) {
        ShowError(L"Failed to create window");
        CoUninitialize();
        return 1;
    }

    ShowWindow(g_hWnd, nCmdShow);
    UpdateWindow(g_hWnd);

    // Initialize WebView2
    if (!InitWebView(g_hWnd)) {
        ShowError(L"Failed to initialize WebView2.\n\nPlease ensure Microsoft Edge WebView2 Runtime is installed.");
        DestroyWindow(g_hWnd);
        CoUninitialize();
        return 1;
    }

    // Start Docker management thread
    g_dockerThread = CreateThread(nullptr, 0, DockerManagerThread, nullptr, 0, nullptr);

    // Message loop
    MSG msg = {};
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    // Cleanup
    g_shutdownRequested = true;
    if (g_dockerThread) {
        WaitForSingleObject(g_dockerThread, 5000);
        CloseHandle(g_dockerThread);
    }

    // Stop the container on exit
    StopDockerContainer();

    CoUninitialize();
    return (int)msg.wParam;
}

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
    case WM_SIZE:
        if (g_webviewController) {
            RECT bounds;
            GetClientRect(hwnd, &bounds);
            g_webviewController->put_Bounds(bounds);
        }
        return 0;

    case WM_DESTROY:
        g_shutdownRequested = true;
        PostQuitMessage(0);
        return 0;

    case WM_USER + 1: // Docker startup failure
        MessageBoxW(hwnd,
            L"Failed to start the game container.\n\n"
            L"Please check that Docker Desktop is running and try again.",
            APP_TITLE, MB_OK | MB_ICONERROR);
        DestroyWindow(hwnd);
        return 0;

    case WM_USER + 2: // Container ready - load URL
        if (g_webview) {
            g_webview->Navigate(NOVNC_URL);
            SetWindowTextW(hwnd, APP_TITLE);
        }
        return 0;

    case WM_USER + 3: // Container stopped unexpectedly
        if (MessageBoxW(hwnd,
            L"The game container has stopped.\n\nWould you like to restart it?",
            APP_TITLE, MB_YESNO | MB_ICONWARNING) == IDYES) {
            // Restart container
            g_dockerThread = CreateThread(nullptr, 0, DockerManagerThread, nullptr, 0, nullptr);
            if (g_webview) {
                g_webview->Navigate(L"about:blank");
            }
            SetWindowTextW(hwnd, L"Fight the Machine - Restarting...");
        } else {
            DestroyWindow(hwnd);
        }
        return 0;

    case WM_KEYDOWN:
        // F11 for fullscreen toggle
        if (wParam == VK_F11) {
            static bool fullscreen = false;
            static WINDOWPLACEMENT wp = { sizeof(wp) };

            if (!fullscreen) {
                GetWindowPlacement(hwnd, &wp);
                SetWindowLongPtr(hwnd, GWL_STYLE, WS_POPUP | WS_VISIBLE);
                SetWindowPos(hwnd, HWND_TOP, 0, 0,
                    GetSystemMetrics(SM_CXSCREEN),
                    GetSystemMetrics(SM_CYSCREEN),
                    SWP_FRAMECHANGED);
            } else {
                SetWindowLongPtr(hwnd, GWL_STYLE, WS_OVERLAPPEDWINDOW | WS_VISIBLE);
                SetWindowPlacement(hwnd, &wp);
            }
            fullscreen = !fullscreen;
        }
        // Escape to exit fullscreen or close
        else if (wParam == VK_ESCAPE) {
            LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
            if (!(style & WS_OVERLAPPEDWINDOW)) {
                // Exit fullscreen
                SendMessage(hwnd, WM_KEYDOWN, VK_F11, 0);
            }
        }
        return 0;
    }

    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

bool InitWebView(HWND hwnd) {
    // Get user data folder for WebView2
    wchar_t userDataFolder[MAX_PATH];
    GetTempPathW(MAX_PATH, userDataFolder);
    wcscat_s(userDataFolder, L"FightTheMachine_WebView2");

    // Create WebView2 environment
    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        nullptr, userDataFolder, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [hwnd](HRESULT result, ICoreWebView2Environment* env) -> HRESULT {
                if (FAILED(result) || !env) {
                    return E_FAIL;
                }

                // Create WebView2 controller
                env->CreateCoreWebView2Controller(hwnd,
                    Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                        [hwnd](HRESULT result, ICoreWebView2Controller* controller) -> HRESULT {
                            if (FAILED(result) || !controller) {
                                return E_FAIL;
                            }

                            g_webviewController = controller;
                            g_webviewController->get_CoreWebView2(&g_webview);

                            // Configure WebView settings
                            ComPtr<ICoreWebView2Settings> settings;
                            g_webview->get_Settings(&settings);
                            settings->put_IsScriptEnabled(TRUE);
                            settings->put_AreDefaultScriptDialogsEnabled(TRUE);
                            settings->put_IsWebMessageEnabled(TRUE);
                            settings->put_AreDevToolsEnabled(FALSE);
                            settings->put_IsStatusBarEnabled(FALSE);

                            // Resize to fill window
                            RECT bounds;
                            GetClientRect(hwnd, &bounds);
                            g_webviewController->put_Bounds(bounds);

                            // Show loading page while container starts
                            g_webview->NavigateToString(
                                L"<!DOCTYPE html>"
                                L"<html><head><style>"
                                L"body { background: #1a1a2e; color: #00ff41; font-family: 'Courier New', monospace; "
                                L"display: flex; flex-direction: column; align-items: center; justify-content: center; "
                                L"height: 100vh; margin: 0; }"
                                L"h1 { font-size: 2.5em; text-shadow: 0 0 10px #00ff41; margin-bottom: 20px; }"
                                L".loader { width: 50px; height: 50px; border: 5px solid #333; "
                                L"border-top: 5px solid #00ff41; border-radius: 50%; animation: spin 1s linear infinite; }"
                                L"@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }"
                                L"p { margin-top: 20px; font-size: 1.2em; }"
                                L".hint { color: #888; font-size: 0.9em; margin-top: 30px; }"
                                L"</style></head><body>"
                                L"<h1>FIGHT THE MACHINE</h1>"
                                L"<div class='loader'></div>"
                                L"<p>Starting game container...</p>"
                                L"<p class='hint'>Press F11 for fullscreen | ESC to exit fullscreen</p>"
                                L"</body></html>"
                            );

                            return S_OK;
                        }).Get());

                return S_OK;
            }).Get());

    return SUCCEEDED(hr);
}

std::wstring GetExecutableDirectory() {
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    PathRemoveFileSpecW(path);
    return std::wstring(path);
}

bool RunCommand(const wchar_t* command, bool wait = true, bool hidden = true) {
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};

    if (hidden) {
        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
    }

    wchar_t cmdLine[4096];
    wcscpy_s(cmdLine, command);

    BOOL result = CreateProcessW(
        nullptr, cmdLine, nullptr, nullptr, FALSE,
        hidden ? CREATE_NO_WINDOW : 0,
        nullptr, nullptr, &si, &pi
    );

    if (!result) {
        return false;
    }

    if (wait) {
        WaitForSingleObject(pi.hProcess, INFINITE);
        DWORD exitCode;
        GetExitCodeProcess(pi.hProcess, &exitCode);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        return exitCode == 0;
    }

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return true;
}

bool IsDockerRunning() {
    return RunCommand(L"docker info");
}

bool IsContainerHealthy() {
    // Check if container is running and healthy
    return RunCommand(L"docker inspect --format=\"{{.State.Health.Status}}\" fightthemachine 2>nul | findstr healthy");
}

bool StartDockerContainer() {
    // Change to project directory and run docker-compose
    std::wstring exeDir = GetExecutableDirectory();

    // Try to find docker-compose.yml in various locations
    std::wstring composeFile;
    std::wstring paths[] = {
        exeDir + L"\\docker-compose.yml",
        exeDir + L"\\..\\docker-compose.yml",
        exeDir + L"\\..\\..\\docker-compose.yml"
    };

    for (const auto& path : paths) {
        if (PathFileExistsW(path.c_str())) {
            composeFile = path;
            break;
        }
    }

    if (composeFile.empty()) {
        // Fall back to pulling from Docker Hub (if published)
        // For now, show error
        return false;
    }

    // Get directory containing compose file
    wchar_t composeDir[MAX_PATH];
    wcscpy_s(composeDir, composeFile.c_str());
    PathRemoveFileSpecW(composeDir);

    // Build the command
    wchar_t command[4096];
    swprintf_s(command, L"cmd /c \"cd /d \"%s\" && docker-compose up -d --build\"", composeDir);

    return RunCommand(command, true, true);
}

bool StopDockerContainer() {
    return RunCommand(L"docker-compose -p fightthemachine down 2>nul || docker stop fightthemachine 2>nul");
}

void ShowError(const wchar_t* message) {
    MessageBoxW(nullptr, message, APP_TITLE, MB_OK | MB_ICONERROR);
}

void ShowStatus(const wchar_t* status) {
    if (g_hWnd) {
        std::wstring title = std::wstring(APP_TITLE) + L" - " + status;
        SetWindowTextW(g_hWnd, title.c_str());
    }
}
