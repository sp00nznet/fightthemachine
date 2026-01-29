// Fight the Machine - QEMU Manager
// Manages QEMU VM lifecycle for the embedded Windows build

#pragma once

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <string>
#include <functional>
#include <atomic>

// Acceleration type detected on the system
enum class QemuAccelType {
    None,       // No acceleration (TCG software emulation)
    WHPX,       // Windows Hypervisor Platform (Hyper-V)
    HAXM,       // Intel Hardware Accelerated Execution Manager
    TCG         // Tiny Code Generator (software emulation)
};

// VM state
enum class QemuVMState {
    Stopped,
    Starting,
    Running,
    Error
};

// Callback types
using StateChangeCallback = std::function<void(QemuVMState state, const std::wstring& message)>;
using HealthCheckCallback = std::function<void(bool healthy)>;

class QemuManager {
public:
    QemuManager();
    ~QemuManager();

    // Initialize the manager and detect paths
    bool Initialize(const std::wstring& basePath);

    // Detect available hardware acceleration
    QemuAccelType DetectAcceleration();
    std::wstring GetAccelerationName(QemuAccelType accel);

    // VM lifecycle
    bool StartVM();
    bool StopVM();
    bool IsVMRunning() const;
    QemuVMState GetState() const;

    // Health checking
    bool IsVMHealthy();
    void StartHealthMonitor(HealthCheckCallback callback, int intervalMs = 2000);
    void StopHealthMonitor();

    // Configuration
    void SetMemoryMB(int mb) { m_memoryMB = mb; }
    void SetCPUCores(int cores) { m_cpuCores = cores; }
    void SetVNCPort(int port) { m_vncPort = port; }
    void SetNoVNCPort(int port) { m_novncPort = port; }
    void SetStateCallback(StateChangeCallback callback) { m_stateCallback = callback; }

    // Get paths
    std::wstring GetQemuPath() const { return m_qemuExePath; }
    std::wstring GetVMImagePath() const { return m_vmImagePath; }
    std::wstring GetNoVNCUrl() const;

    // Error information
    std::wstring GetLastError() const { return m_lastError; }

private:
    // Find QEMU executable in various locations
    bool FindQemuExecutable();
    bool FindVMImage();

    // Build QEMU command line
    std::wstring BuildCommandLine();

    // Process management
    bool LaunchProcess(const std::wstring& commandLine);
    bool TerminateProcess();

    // Health monitoring thread
    static DWORD WINAPI HealthMonitorThread(LPVOID lpParam);

    // State management
    void SetState(QemuVMState state, const std::wstring& message = L"");

    // Paths
    std::wstring m_basePath;
    std::wstring m_qemuExePath;
    std::wstring m_vmImagePath;
    std::wstring m_qemuDir;

    // Configuration
    int m_memoryMB = 512;
    int m_cpuCores = 2;
    int m_vncPort = 5900;
    int m_novncPort = 6080;
    QemuAccelType m_accelType = QemuAccelType::None;

    // Process handles
    HANDLE m_qemuProcess = nullptr;
    HANDLE m_qemuThread = nullptr;
    DWORD m_qemuPID = 0;

    // Health monitor
    HANDLE m_healthThread = nullptr;
    std::atomic<bool> m_healthMonitorRunning{false};
    HealthCheckCallback m_healthCallback;
    int m_healthInterval = 2000;

    // State
    std::atomic<QemuVMState> m_state{QemuVMState::Stopped};
    StateChangeCallback m_stateCallback;
    std::wstring m_lastError;

    // Prevent copying
    QemuManager(const QemuManager&) = delete;
    QemuManager& operator=(const QemuManager&) = delete;
};
