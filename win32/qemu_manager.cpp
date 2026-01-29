// Fight the Machine - QEMU Manager Implementation
// Manages QEMU VM lifecycle for the embedded Windows build

#include "qemu_manager.h"
#include <shlwapi.h>
#include <winhttp.h>
#include <sstream>
#include <thread>
#include <chrono>

#pragma comment(lib, "shlwapi.lib")
#pragma comment(lib, "winhttp.lib")

QemuManager::QemuManager() {
}

QemuManager::~QemuManager() {
    StopHealthMonitor();
    StopVM();
}

bool QemuManager::Initialize(const std::wstring& basePath) {
    m_basePath = basePath;

    // Find QEMU executable
    if (!FindQemuExecutable()) {
        m_lastError = L"QEMU executable not found. Please ensure QEMU is installed.";
        return false;
    }

    // Find VM image
    if (!FindVMImage()) {
        m_lastError = L"VM image not found. Please ensure fightthemachine.qcow2 exists.";
        return false;
    }

    // Detect acceleration
    m_accelType = DetectAcceleration();

    return true;
}

bool QemuManager::FindQemuExecutable() {
    // Search paths for QEMU executable
    std::wstring searchPaths[] = {
        m_basePath + L"\\qemu\\qemu-system-x86_64w.exe",  // GUI version (preferred)
        m_basePath + L"\\qemu\\qemu-system-x86_64.exe",
        L"C:\\Program Files\\qemu\\qemu-system-x86_64w.exe",
        L"C:\\Program Files\\qemu\\qemu-system-x86_64.exe",
        L"C:\\Program Files (x86)\\qemu\\qemu-system-x86_64.exe",
    };

    for (const auto& path : searchPaths) {
        if (PathFileExistsW(path.c_str())) {
            m_qemuExePath = path;
            // Set QEMU directory for finding firmware/BIOS files
            wchar_t dir[MAX_PATH];
            wcscpy_s(dir, path.c_str());
            PathRemoveFileSpecW(dir);
            m_qemuDir = dir;
            return true;
        }
    }

    // Try PATH environment
    wchar_t foundPath[MAX_PATH];
    if (SearchPathW(nullptr, L"qemu-system-x86_64.exe", nullptr, MAX_PATH, foundPath, nullptr)) {
        m_qemuExePath = foundPath;
        PathRemoveFileSpecW(foundPath);
        m_qemuDir = foundPath;
        return true;
    }

    return false;
}

bool QemuManager::FindVMImage() {
    // Search paths for VM image
    std::wstring searchPaths[] = {
        m_basePath + L"\\vm\\fightthemachine.qcow2",
        m_basePath + L"\\fightthemachine.qcow2",
        m_basePath + L"\\qemu\\fightthemachine.qcow2",
    };

    for (const auto& path : searchPaths) {
        if (PathFileExistsW(path.c_str())) {
            m_vmImagePath = path;
            return true;
        }
    }

    return false;
}

QemuAccelType QemuManager::DetectAcceleration() {
    // Check for WHPX (Windows Hypervisor Platform)
    // WHPX is available when Hyper-V is enabled
    HMODULE hWHvPlatform = LoadLibraryW(L"WinHvPlatform.dll");
    if (hWHvPlatform) {
        // Try to call WHvGetCapability to verify it works
        typedef HRESULT(WINAPI* WHvGetCapabilityFunc)(int, void*, UINT32, UINT32*);
        auto WHvGetCapability = (WHvGetCapabilityFunc)GetProcAddress(hWHvPlatform, "WHvGetCapability");
        if (WHvGetCapability) {
            BOOL hypervisorPresent = FALSE;
            UINT32 written = 0;
            // WHvCapabilityCodeHypervisorPresent = 0
            if (SUCCEEDED(WHvGetCapability(0, &hypervisorPresent, sizeof(BOOL), &written))) {
                if (hypervisorPresent) {
                    FreeLibrary(hWHvPlatform);
                    return QemuAccelType::WHPX;
                }
            }
        }
        FreeLibrary(hWHvPlatform);
    }

    // Check for HAXM (Intel Hardware Accelerated Execution Manager)
    HANDLE hHaxm = CreateFileW(
        L"\\\\.\\HAX",
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        nullptr
    );
    if (hHaxm != INVALID_HANDLE_VALUE) {
        CloseHandle(hHaxm);
        return QemuAccelType::HAXM;
    }

    // Fall back to TCG (software emulation)
    return QemuAccelType::TCG;
}

std::wstring QemuManager::GetAccelerationName(QemuAccelType accel) {
    switch (accel) {
    case QemuAccelType::WHPX:
        return L"WHPX (Windows Hypervisor Platform)";
    case QemuAccelType::HAXM:
        return L"HAXM (Intel Hardware Accelerated Execution Manager)";
    case QemuAccelType::TCG:
        return L"TCG (Software Emulation)";
    default:
        return L"None";
    }
}

std::wstring QemuManager::BuildCommandLine() {
    std::wstringstream cmd;

    cmd << L"\"" << m_qemuExePath << L"\"";

    // Memory and CPU
    cmd << L" -m " << m_memoryMB << L"M";
    cmd << L" -smp " << m_cpuCores;

    // Disk image
    cmd << L" -hda \"" << m_vmImagePath << L"\"";

    // Network with port forwarding
    cmd << L" -netdev user,id=net0";
    cmd << L",hostfwd=tcp::" << m_novncPort << L"-:6080";
    cmd << L",hostfwd=tcp::" << m_vncPort << L"-:5900";
    cmd << L" -device virtio-net,netdev=net0";

    // Display - run headless, access via VNC/noVNC
    cmd << L" -vga virtio";
    cmd << L" -display none";

    // Acceleration
    switch (m_accelType) {
    case QemuAccelType::WHPX:
        cmd << L" -accel whpx";
        break;
    case QemuAccelType::HAXM:
        cmd << L" -accel hax";
        break;
    case QemuAccelType::TCG:
    default:
        cmd << L" -accel tcg";
        break;
    }

    // Boot options
    cmd << L" -boot c";

    // Firmware path (if available)
    std::wstring biosPath = m_qemuDir + L"\\bios-256k.bin";
    if (PathFileExistsW(biosPath.c_str())) {
        cmd << L" -L \"" << m_qemuDir << L"\"";
    }

    return cmd.str();
}

bool QemuManager::LaunchProcess(const std::wstring& commandLine) {
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};

    // Hide the console window
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;

    // Make a mutable copy of the command line
    std::wstring cmdLine = commandLine;

    BOOL result = CreateProcessW(
        nullptr,
        &cmdLine[0],
        nullptr,
        nullptr,
        FALSE,
        CREATE_NO_WINDOW,
        nullptr,
        m_qemuDir.c_str(),  // Working directory
        &si,
        &pi
    );

    if (!result) {
        DWORD error = GetLastError();
        wchar_t buf[256];
        swprintf_s(buf, L"Failed to start QEMU (error %lu)", error);
        m_lastError = buf;
        return false;
    }

    m_qemuProcess = pi.hProcess;
    m_qemuThread = pi.hThread;
    m_qemuPID = pi.dwProcessId;

    return true;
}

bool QemuManager::TerminateProcess() {
    if (m_qemuProcess) {
        // Try graceful shutdown first (QEMU monitor command)
        // For now, just terminate
        ::TerminateProcess(m_qemuProcess, 0);
        WaitForSingleObject(m_qemuProcess, 5000);

        CloseHandle(m_qemuProcess);
        CloseHandle(m_qemuThread);
        m_qemuProcess = nullptr;
        m_qemuThread = nullptr;
        m_qemuPID = 0;
    }
    return true;
}

bool QemuManager::StartVM() {
    if (m_state == QemuVMState::Running || m_state == QemuVMState::Starting) {
        return true;  // Already running
    }

    SetState(QemuVMState::Starting, L"Building command line...");

    std::wstring cmdLine = BuildCommandLine();

    SetState(QemuVMState::Starting, L"Launching QEMU...");

    if (!LaunchProcess(cmdLine)) {
        SetState(QemuVMState::Error, m_lastError);
        return false;
    }

    SetState(QemuVMState::Starting, L"Waiting for VM to boot...");

    // Wait for the VM to become healthy (noVNC responds)
    auto startTime = std::chrono::steady_clock::now();
    const int timeoutMs = 60000;  // 60 second timeout

    while (true) {
        // Check if process is still running
        DWORD exitCode;
        if (GetExitCodeProcess(m_qemuProcess, &exitCode) && exitCode != STILL_ACTIVE) {
            m_lastError = L"QEMU process exited unexpectedly";
            SetState(QemuVMState::Error, m_lastError);
            return false;
        }

        // Check if noVNC is responding
        if (IsVMHealthy()) {
            SetState(QemuVMState::Running, L"VM is running");
            return true;
        }

        // Check timeout
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - startTime
        ).count();

        if (elapsed > timeoutMs) {
            m_lastError = L"VM startup timeout - noVNC not responding";
            SetState(QemuVMState::Error, m_lastError);
            StopVM();
            return false;
        }

        Sleep(500);
    }
}

bool QemuManager::StopVM() {
    StopHealthMonitor();

    if (m_qemuProcess) {
        SetState(QemuVMState::Stopped, L"Stopping VM...");
        TerminateProcess();
    }

    SetState(QemuVMState::Stopped, L"VM stopped");
    return true;
}

bool QemuManager::IsVMRunning() const {
    if (!m_qemuProcess) return false;

    DWORD exitCode;
    if (GetExitCodeProcess(m_qemuProcess, &exitCode)) {
        return exitCode == STILL_ACTIVE;
    }
    return false;
}

QemuVMState QemuManager::GetState() const {
    return m_state;
}

bool QemuManager::IsVMHealthy() {
    // Try to connect to noVNC endpoint
    HINTERNET hSession = WinHttpOpen(
        L"FightTheMachine/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
        WINHTTP_NO_PROXY_NAME,
        WINHTTP_NO_PROXY_BYPASS,
        0
    );

    if (!hSession) return false;

    wchar_t host[32];
    swprintf_s(host, L"localhost");

    HINTERNET hConnect = WinHttpConnect(hSession, host, (INTERNET_PORT)m_novncPort, 0);
    if (!hConnect) {
        WinHttpCloseHandle(hSession);
        return false;
    }

    HINTERNET hRequest = WinHttpOpenRequest(
        hConnect,
        L"GET",
        L"/",
        nullptr,
        WINHTTP_NO_REFERER,
        WINHTTP_DEFAULT_ACCEPT_TYPES,
        0
    );

    if (!hRequest) {
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    // Set short timeouts
    DWORD timeout = 2000;
    WinHttpSetOption(hRequest, WINHTTP_OPTION_CONNECT_TIMEOUT, &timeout, sizeof(timeout));
    WinHttpSetOption(hRequest, WINHTTP_OPTION_RECEIVE_TIMEOUT, &timeout, sizeof(timeout));

    BOOL result = WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0);
    if (result) {
        result = WinHttpReceiveResponse(hRequest, nullptr);
    }

    bool healthy = false;
    if (result) {
        DWORD statusCode = 0;
        DWORD statusCodeSize = sizeof(statusCode);
        if (WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
            WINHTTP_HEADER_NAME_BY_INDEX, &statusCode, &statusCodeSize, WINHTTP_NO_HEADER_INDEX)) {
            healthy = (statusCode == 200 || statusCode == 301 || statusCode == 302);
        }
    }

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);

    return healthy;
}

DWORD WINAPI QemuManager::HealthMonitorThread(LPVOID lpParam) {
    QemuManager* manager = static_cast<QemuManager*>(lpParam);

    while (manager->m_healthMonitorRunning) {
        bool healthy = manager->IsVMHealthy() && manager->IsVMRunning();

        if (manager->m_healthCallback) {
            manager->m_healthCallback(healthy);
        }

        if (!healthy && manager->m_state == QemuVMState::Running) {
            manager->SetState(QemuVMState::Error, L"VM health check failed");
        }

        Sleep(manager->m_healthInterval);
    }

    return 0;
}

void QemuManager::StartHealthMonitor(HealthCheckCallback callback, int intervalMs) {
    if (m_healthMonitorRunning) return;

    m_healthCallback = callback;
    m_healthInterval = intervalMs;
    m_healthMonitorRunning = true;

    m_healthThread = CreateThread(nullptr, 0, HealthMonitorThread, this, 0, nullptr);
}

void QemuManager::StopHealthMonitor() {
    if (m_healthMonitorRunning) {
        m_healthMonitorRunning = false;
        if (m_healthThread) {
            WaitForSingleObject(m_healthThread, 5000);
            CloseHandle(m_healthThread);
            m_healthThread = nullptr;
        }
    }
}

std::wstring QemuManager::GetNoVNCUrl() const {
    wchar_t url[256];
    swprintf_s(url, L"http://localhost:%d/vnc.html?autoconnect=true&resize=scale", m_novncPort);
    return url;
}

void QemuManager::SetState(QemuVMState state, const std::wstring& message) {
    m_state = state;
    if (m_stateCallback) {
        m_stateCallback(state, message);
    }
}
