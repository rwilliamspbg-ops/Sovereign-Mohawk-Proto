//go:build windows

// Copyright 2026 Sovereign-Mohawk Core Team
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package main

import (
	"bytes"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

const (
	windowClassName = "SovereignMohawkTestnetControlWindow"
	windowTitle     = "Sovereign Mohawk Testnet Control"
	timerRefreshID  = 1

	idStatusLabel      = 1001
	idStatusEdit       = 1002
	idStartFullStack   = 2001
	idStartGenesis     = 2002
	idStopStack        = 2003
	idRefreshStatus    = 2004
	idOpenGrafana      = 2005
	idOpenPrometheus   = 2006
	idOpenOrchestrator = 2007
	idOpenReadme       = 2008

	wsOverlappedWindow = 0x00CF0000
	wsVisible          = 0x10000000
	wsChild            = 0x40000000
	wsTabstop          = 0x00010000
	wsBorder           = 0x00800000
	wsVScroll          = 0x00200000
	wsDisabled         = 0x08000000

	swShow = 5

	wmCreate  = 0x0001
	wmDestroy = 0x0002
	wmSize    = 0x0005
	wmCommand = 0x0111
	wmTimer   = 0x0113

	bnClicked = 0

	esMultiline   = 0x0004
	esAutovScroll = 0x0040
	esReadOnly    = 0x0800
	esWantReturn  = 0x1000
	esNoHideSel   = 0x0100

	wsExClientEdge = 0x00000200
	colorWindow    = 5
)

var (
	user32   = syscall.NewLazyDLL("user32.dll")
	kernel32 = syscall.NewLazyDLL("kernel32.dll")
	shell32  = syscall.NewLazyDLL("shell32.dll")

	procDefWindowProcW   = user32.NewProc("DefWindowProcW")
	procRegisterClassExW = user32.NewProc("RegisterClassExW")
	procCreateWindowExW  = user32.NewProc("CreateWindowExW")
	procShowWindow       = user32.NewProc("ShowWindow")
	procUpdateWindow     = user32.NewProc("UpdateWindow")
	procGetMessageW      = user32.NewProc("GetMessageW")
	procTranslateMessage = user32.NewProc("TranslateMessage")
	procDispatchMessageW = user32.NewProc("DispatchMessageW")
	procPostQuitMessage  = user32.NewProc("PostQuitMessage")
	procSetWindowTextW   = user32.NewProc("SetWindowTextW")
	procMoveWindow       = user32.NewProc("MoveWindow")
	procSetTimer         = user32.NewProc("SetTimer")
	procKillTimer        = user32.NewProc("KillTimer")
	procGetClientRect    = user32.NewProc("GetClientRect")
	procEnableWindow     = user32.NewProc("EnableWindow")
	procLoadCursorW      = user32.NewProc("LoadCursorW")
	procGetSystemMetrics = user32.NewProc("GetSystemMetrics")
	procShellExecuteW    = shell32.NewProc("ShellExecuteW")
	procGetModuleHandleW = kernel32.NewProc("GetModuleHandleW")
)

type desktopApp struct {
	launcher   *launcher
	hwnd       syscall.Handle
	statusEdit syscall.Handle
	statusLine syscall.Handle
	buttons    map[int]syscall.Handle
	lastError  string
	mu         sync.Mutex
}

type launcher struct {
	repoRoot string
	runner   *commandRunner
}

type commandRunner struct {
	mu         sync.Mutex
	running    bool
	label      string
	command    string
	startedAt  time.Time
	finishedAt time.Time
	exitError  string
	buffer     capturedOutput
}

type capturedOutput struct {
	mu  sync.Mutex
	buf bytes.Buffer
}

type serviceStatus struct {
	Name     string `json:"name"`
	Endpoint string `json:"endpoint"`
	Status   string `json:"status"`
	Detail   string `json:"detail,omitempty"`
}

type runnerSnapshot struct {
	Running    bool     `json:"running"`
	Label      string   `json:"label"`
	Command    string   `json:"command"`
	StartedAt  string   `json:"started_at,omitempty"`
	FinishedAt string   `json:"finished_at,omitempty"`
	ExitError  string   `json:"exit_error,omitempty"`
	Output     []string `json:"output"`
}

type statusResponse struct {
	Timestamp      time.Time       `json:"timestamp"`
	RepoRoot       string          `json:"repo_root"`
	ShellLabel     string          `json:"shell_label"`
	DockerOK       bool            `json:"docker_ok"`
	DockerDetail   string          `json:"docker_detail,omitempty"`
	StackState     string          `json:"stack_state"`
	StackStateKind string          `json:"stack_state_kind"`
	StackSummary   string          `json:"stack_summary"`
	TotalServices  int             `json:"total_services"`
	OnlineServices int             `json:"online_services"`
	ExpectedNodes  int             `json:"expected_nodes"`
	OnlineNodes    int             `json:"online_nodes"`
	Runner         runnerSnapshot  `json:"runner"`
	Services       []serviceStatus `json:"services"`
}

var currentApp *desktopApp

func main() {
	runtime.LockOSThread()

	repoRoot, err := findRepoRoot()
	if err != nil {
		log.Fatal(err)
	}

	currentApp = &desktopApp{
		launcher: &launcher{
			repoRoot: repoRoot,
			runner:   &commandRunner{},
		},
		buttons: make(map[int]syscall.Handle),
	}

	if err := currentApp.run(); err != nil {
		log.Fatal(err)
	}
}

func (a *desktopApp) run() error {
	hInstance := mustGetModuleHandle()
	className := utf16Ptr(windowClassName)
	wndProc := syscall.NewCallback(windowProc)
	cursor := mustLoadCursor(32512)

	wc := wndClassEx{
		cbSize:        uint32(unsafe.Sizeof(wndClassEx{})),
		style:         0,
		lpfnWndProc:   wndProc,
		cbClsExtra:    0,
		cbWndExtra:    0,
		hInstance:     hInstance,
		hIcon:         0,
		hCursor:       cursor,
		hbrBackground: syscall.Handle(colorWindow + 1),
		lpszMenuName:  nil,
		lpszClassName: className,
		hIconSm:       0,
	}

	if r, _, err := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc))); r == 0 {
		return err
	}

	hwnd, _, err := procCreateWindowExW.Call(
		0,
		uintptr(unsafe.Pointer(className)),
		uintptr(unsafe.Pointer(utf16Ptr(windowTitle))),
		uintptr(wsOverlappedWindow|wsVisible),
		uintptr(int32(120)),
		uintptr(int32(120)),
		uintptr(int32(1260)),
		uintptr(int32(860)),
		0,
		0,
		uintptr(hInstance),
		0,
	)
	if hwnd == 0 {
		return err
	}

	a.hwnd = syscall.Handle(hwnd)
	procShowWindow.Call(hwnd, swShow)
	procUpdateWindow.Call(hwnd)

	var msg msg
	for {
		r, _, _ := procGetMessageW.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
		if int32(r) <= 0 {
			break
		}
		procTranslateMessage.Call(uintptr(unsafe.Pointer(&msg)))
		procDispatchMessageW.Call(uintptr(unsafe.Pointer(&msg)))
	}

	return nil
}

func windowProc(hwnd uintptr, msg uint32, wParam, lParam uintptr) uintptr {
	app := currentApp
	if app == nil {
		ret, _, _ := procDefWindowProcW.Call(hwnd, uintptr(msg), wParam, lParam)
		return ret
	}

	switch msg {
	case wmCreate:
		app.hwnd = syscall.Handle(hwnd)
		app.createControls()
		app.refreshUI()
		procSetTimer.Call(hwnd, timerRefreshID, 3000, 0)
		return 0
	case wmSize:
		app.layoutControls()
		return 0
	case wmCommand:
		id := int(uint16(wParam & 0xffff))
		code := int(uint16((wParam >> 16) & 0xffff))
		if code == bnClicked {
			app.handleCommand(id)
		}
		return 0
	case wmTimer:
		if int(wParam) == timerRefreshID {
			app.refreshUI()
		}
		return 0
	case wmDestroy:
		procKillTimer.Call(hwnd, timerRefreshID)
		procPostQuitMessage.Call(0)
		return 0
	default:
		ret, _, _ := procDefWindowProcW.Call(hwnd, uintptr(msg), wParam, lParam)
		return ret
	}
}

func (a *desktopApp) createControls() {
	a.statusLine = a.createStatic(utf16Ptr("Initializing native testnet window..."), 16, 14, 1180, 22)
	a.statusEdit = a.createEdit(16, 150, 1180, 640)

	buttons := []struct {
		id    int
		label string
	}{
		{idStartFullStack, "Start Full Stack"},
		{idStartGenesis, "Start Genesis"},
		{idStopStack, "Stop Stack"},
		{idRefreshStatus, "Refresh"},
		{idOpenGrafana, "Open Grafana"},
		{idOpenPrometheus, "Open Prometheus"},
		{idOpenOrchestrator, "Open Orchestrator"},
		{idOpenReadme, "Open README"},
	}

	for _, button := range buttons {
		a.buttons[button.id] = a.createButton(button.id, utf16Ptr(button.label), 0, 0, 120, 28)
	}

	a.layoutControls()
}

func (a *desktopApp) layoutControls() {
	if a.hwnd == 0 {
		return
	}
	var rc rect
	procGetClientRect.Call(uintptr(a.hwnd), uintptr(unsafe.Pointer(&rc)))
	width := int(rc.Right - rc.Left)
	height := int(rc.Bottom - rc.Top)
	margin := 16
	gap := 8
	buttonHeight := 30
	buttonWidth := (width - margin*2 - gap*3) / 4
	if buttonWidth < 120 {
		buttonWidth = 120
	}
	row1Y := 54
	row2Y := row1Y + buttonHeight + gap
	editY := row2Y + buttonHeight + 16
	editHeight := height - editY - margin
	if editHeight < 180 {
		editHeight = 180
	}

	moveWindow(a.statusLine, margin, 14, width-margin*2, 22)

	buttonOrder := []int{idStartFullStack, idStartGenesis, idStopStack, idRefreshStatus, idOpenGrafana, idOpenPrometheus, idOpenOrchestrator, idOpenReadme}
	for i, id := range buttonOrder {
		handle := a.buttons[id]
		if handle == 0 {
			continue
		}
		row := 0
		col := i
		if i >= 4 {
			row = 1
			col = i - 4
		}
		x := margin + col*(buttonWidth+gap)
		y := row1Y + row*(buttonHeight+gap)
		moveWindow(handle, x, y, buttonWidth, buttonHeight)
	}

	moveWindow(a.statusEdit, margin, editY, width-margin*2, editHeight)
}

func (a *desktopApp) createStatic(text *uint16, x, y, width, height int) syscall.Handle {
	hwnd, _, _ := procCreateWindowExW.Call(
		0,
		uintptr(unsafe.Pointer(utf16Ptr("STATIC"))),
		uintptr(unsafe.Pointer(text)),
		uintptr(wsChild|wsVisible),
		uintptr(int32(x)),
		uintptr(int32(y)),
		uintptr(int32(width)),
		uintptr(int32(height)),
		uintptr(a.hwnd),
		0,
		uintptr(mustGetModuleHandle()),
		0,
	)
	return syscall.Handle(hwnd)
}

func (a *desktopApp) createButton(id int, text *uint16, x, y, width, height int) syscall.Handle {
	hwnd, _, _ := procCreateWindowExW.Call(
		0,
		uintptr(unsafe.Pointer(utf16Ptr("BUTTON"))),
		uintptr(unsafe.Pointer(text)),
		uintptr(wsChild|wsVisible|wsTabstop),
		uintptr(int32(x)),
		uintptr(int32(y)),
		uintptr(int32(width)),
		uintptr(int32(height)),
		uintptr(a.hwnd),
		uintptr(syscall.Handle(id)),
		uintptr(mustGetModuleHandle()),
		0,
	)
	return syscall.Handle(hwnd)
}

func (a *desktopApp) createEdit(x, y, width, height int) syscall.Handle {
	style := wsChild | wsVisible | wsBorder | wsVScroll | esMultiline | esAutovScroll | esReadOnly | esWantReturn | esNoHideSel
	exStyle := wsExClientEdge
	hwnd, _, _ := procCreateWindowExW.Call(
		uintptr(exStyle),
		uintptr(unsafe.Pointer(utf16Ptr("EDIT"))),
		uintptr(unsafe.Pointer(utf16Ptr(""))),
		uintptr(style),
		uintptr(int32(x)),
		uintptr(int32(y)),
		uintptr(int32(width)),
		uintptr(int32(height)),
		uintptr(a.hwnd),
		uintptr(syscall.Handle(idStatusEdit)),
		uintptr(mustGetModuleHandle()),
		0,
	)
	return syscall.Handle(hwnd)
}

func (a *desktopApp) handleCommand(id int) {
	switch id {
	case idStartFullStack:
		if err := a.launcher.startFullStack(); err != nil {
			a.lastError = err.Error()
		} else {
			a.lastError = ""
		}
	case idStartGenesis:
		if err := a.launcher.startGenesis(); err != nil {
			a.lastError = err.Error()
		} else {
			a.lastError = ""
		}
	case idStopStack:
		if err := a.launcher.stopStack(); err != nil {
			a.lastError = err.Error()
		} else {
			a.lastError = ""
		}
	case idRefreshStatus:
		// Keep the timer-driven refresh behavior but allow explicit refresh.
		a.lastError = ""
	case idOpenGrafana:
		if err := openTarget("grafana"); err != nil {
			a.lastError = err.Error()
		}
	case idOpenPrometheus:
		if err := openTarget("prometheus"); err != nil {
			a.lastError = err.Error()
		}
	case idOpenOrchestrator:
		if err := openTarget("orchestrator"); err != nil {
			a.lastError = err.Error()
		}
	case idOpenReadme:
		if err := openTarget("readme"); err != nil {
			a.lastError = err.Error()
		}
	}
	a.refreshUI()
}

func (a *desktopApp) refreshUI() {
	status := a.launcher.snapshotStatus()
	if a.lastError == "" {
		statusText := fmt.Sprintf("Stack: %s | Docker: %s | Services: %d/%d | Nodes: %d/%d",
			status.StackState,
			dockerLabel(status.DockerOK),
			status.OnlineServices,
			status.TotalServices,
			status.OnlineNodes,
			status.ExpectedNodes,
		)
		setWindowText(a.statusLine, utf16Ptr(statusText))
	} else {
		setWindowText(a.statusLine, utf16Ptr("Error: "+a.lastError))
	}

	updateButtonsEnabled(a.buttons, !status.Runner.Running)
	setWindowText(a.statusEdit, utf16Ptr(renderDesktopStatus(status, a.lastError)))
}

func renderDesktopStatus(status statusResponse, lastError string) string {
	var b strings.Builder
	b.WriteString("TESTNET STATUS\r\n")
	b.WriteString(strings.Repeat("=", 72))
	b.WriteString("\r\n")
	fmt.Fprintf(&b, "State: %s\r\n", status.StackState)
	fmt.Fprintf(&b, "Summary: %s\r\n", status.StackSummary)
	fmt.Fprintf(&b, "Docker: %s (%s)\r\n", dockerLabel(status.DockerOK), status.DockerDetail)
	fmt.Fprintf(&b, "Shell: %s\r\n", status.ShellLabel)
	fmt.Fprintf(&b, "Services online: %d/%d\r\n", status.OnlineServices, status.TotalServices)
	fmt.Fprintf(&b, "Node agents online: %d/%d\r\n", status.OnlineNodes, status.ExpectedNodes)
	b.WriteString("\r\nSERVICE MAP\r\n")
	for _, service := range status.Services {
		fmt.Fprintf(&b, "- %-22s %-10s %s\r\n", service.Name, service.Status, service.Endpoint)
		if service.Detail != "" {
			fmt.Fprintf(&b, "  %s\r\n", service.Detail)
		}
	}
	b.WriteString("\r\nCOMMAND RUNNER\r\n")
	if status.Runner.Running {
		fmt.Fprintf(&b, "Active: %s\r\n", status.Runner.Label)
		fmt.Fprintf(&b, "Command: %s\r\n", status.Runner.Command)
		fmt.Fprintf(&b, "Started: %s\r\n", status.Runner.StartedAt)
	} else if status.Runner.FinishedAt != "" {
		fmt.Fprintf(&b, "Last: %s\r\n", status.Runner.Label)
		fmt.Fprintf(&b, "Finished: %s\r\n", status.Runner.FinishedAt)
		if status.Runner.ExitError != "" {
			fmt.Fprintf(&b, "Error: %s\r\n", status.Runner.ExitError)
		}
	} else {
		b.WriteString("Idle\r\n")
	}
	if len(status.Runner.Output) > 0 {
		b.WriteString("\r\nRecent output:\r\n")
		for _, line := range status.Runner.Output {
			b.WriteString(line)
			b.WriteString("\r\n")
		}
	}
	if lastError != "" {
		b.WriteString("\r\nLast error: ")
		b.WriteString(lastError)
		b.WriteString("\r\n")
	}
	return b.String()
}

func updateButtonsEnabled(buttons map[int]syscall.Handle, enabled bool) {
	for id, handle := range buttons {
		if id == idRefreshStatus || id == idOpenGrafana || id == idOpenPrometheus || id == idOpenOrchestrator || id == idOpenReadme {
			continue
		}
		procEnableWindow.Call(uintptr(handle), boolToUintptr(enabled))
	}
}

func boolToUintptr(v bool) uintptr {
	if v {
		return 1
	}
	return 0
}

func setWindowText(hwnd syscall.Handle, text *uint16) {
	procSetWindowTextW.Call(uintptr(hwnd), uintptr(unsafe.Pointer(text)))
}

func moveWindow(hwnd syscall.Handle, x, y, width, height int) {
	procMoveWindow.Call(uintptr(hwnd), uintptr(int32(x)), uintptr(int32(y)), uintptr(int32(width)), uintptr(int32(height)), 1)
}

func openTarget(target string) error {
	url, ok := openTargetURL(target)
	if !ok {
		return errors.New("unknown target: " + target)
	}
	r, _, err := procShellExecuteW.Call(
		0,
		uintptr(unsafe.Pointer(utf16Ptr("open"))),
		uintptr(unsafe.Pointer(utf16Ptr(url))),
		0,
		0,
		1,
	)
	if r <= 32 {
		if err != syscall.Errno(0) {
			return err
		}
		return errors.New("unable to open " + target)
	}
	return nil
}

func (a *launcher) snapshotStatus() statusResponse {
	dockerOK, dockerDetail := checkDocker()
	services, onlineServices, onlineNodes := a.collectServices()
	stackState, stackKind, stackSummary := summarizeStack(services, dockerOK)

	return statusResponse{
		Timestamp:      time.Now().UTC(),
		RepoRoot:       a.repoRoot,
		ShellLabel:     a.shellLabel(),
		DockerOK:       dockerOK,
		DockerDetail:   dockerDetail,
		StackState:     stackState,
		StackStateKind: stackKind,
		StackSummary:   stackSummary,
		TotalServices:  len(services),
		OnlineServices: onlineServices,
		ExpectedNodes:  3,
		OnlineNodes:    onlineNodes,
		Runner:         a.runner.snapshot(),
		Services:       services,
	}
}

func (a *launcher) collectServices() ([]serviceStatus, int, int) {
	services := []serviceStatus{
		{Name: "orchestrator", Endpoint: "https://localhost:8080", Status: inspectContainer("orchestrator", "mTLS control plane")},
		{Name: "shard-us-east", Endpoint: "compose", Status: inspectContainer("shard-us-east", "regional shard bootstrap")},
		{Name: "node-agent-1", Endpoint: "compose", Status: inspectContainer("node-agent-1", "edge node")},
		{Name: "node-agent-2", Endpoint: "compose", Status: inspectContainer("node-agent-2", "edge node")},
		{Name: "node-agent-3", Endpoint: "compose", Status: inspectContainer("node-agent-3", "edge node")},
		{Name: "federated-router", Endpoint: "http://localhost:3000", Status: inspectContainer("federated-router", "router and dashboard sidecar")},
		{Name: "prometheus", Endpoint: "http://localhost:9090", Status: inspectHTTP("http://localhost:9090/-/healthy", "metrics query and scrape state")},
		{Name: "grafana", Endpoint: "http://localhost:3000", Status: inspectHTTP("http://localhost:3000/api/health", "dashboard UI")},
		{Name: "tpm-metrics", Endpoint: "http://localhost:9102/metrics", Status: inspectHTTP("http://localhost:9102/metrics", "attestation metrics export")},
		{Name: "pyapi-metrics-exporter", Endpoint: "http://localhost:9103/metrics", Status: inspectContainer("pyapi-metrics-exporter", "Python SDK metrics export")},
		{Name: "ipfs", Endpoint: "compose", Status: inspectContainer("ipfs", "artifact store")},
	}

	onlineServices := 0
	onlineNodes := 0
	for idx := range services {
		if isServiceOnline(services[idx].Status) {
			onlineServices++
		}
		if strings.HasPrefix(services[idx].Name, "node-agent-") && isServiceOnline(services[idx].Status) {
			onlineNodes++
		}
	}

	return services, onlineServices, onlineNodes
}

func (a *launcher) startFullStack() error {
	if a.runner.snapshot().Running {
		return errors.New("a launcher command is already running")
	}
	command, args, err := a.fullStackLauncher()
	if err != nil {
		return err
	}
	return a.runner.run(a.repoRoot, "full stack", command, args...)
}

func (a *launcher) startGenesis() error {
	if a.runner.snapshot().Running {
		return errors.New("a launcher command is already running")
	}
	command, args, err := a.genesisLauncher()
	if err != nil {
		return err
	}
	return a.runner.run(a.repoRoot, "genesis", command, args...)
}

func (a *launcher) stopStack() error {
	if a.runner.snapshot().Running {
		return errors.New("wait for the current launcher command to finish before stopping")
	}
	command, args, err := a.stopLauncher()
	if err != nil {
		return err
	}
	return a.runner.run(a.repoRoot, "stop stack", command, args...)
}

func (a *launcher) shellLabel() string {
	if path, err := exec.LookPath("powershell.exe"); err == nil && path != "" {
		return "PowerShell"
	}
	if path, err := exec.LookPath("pwsh"); err == nil && path != "" {
		return "PowerShell Core"
	}
	if path, err := exec.LookPath("bash"); err == nil && path != "" {
		return "Bash"
	}
	return "Unavailable"
}

func (a *launcher) fullStackLauncher() (string, []string, error) {
	if path, err := exec.LookPath("powershell.exe"); err == nil && path != "" {
		return path, []string{"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", filepath.Join(a.repoRoot, "scripts", "launch_full_stack_3_nodes.ps1"), "-NoBuild"}, nil
	}
	if path, err := exec.LookPath("pwsh"); err == nil && path != "" {
		return path, []string{"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", filepath.Join(a.repoRoot, "scripts", "launch_full_stack_3_nodes.ps1"), "-NoBuild"}, nil
	}
	if path, err := exec.LookPath("bash"); err == nil && path != "" {
		return path, []string{filepath.Join(a.repoRoot, "scripts", "launch_full_stack_3_nodes.sh"), "--no-build"}, nil
	}
	return "", nil, errors.New("no supported shell found: install PowerShell or Bash")
}

func (a *launcher) genesisLauncher() (string, []string, error) {
	if path, err := exec.LookPath("bash"); err == nil && path != "" {
		return path, []string{filepath.Join(a.repoRoot, "genesis-launch.sh"), "--all-nodes"}, nil
	}
	return "", nil, errors.New("genesis mode requires Bash to run genesis-launch.sh")
}

func (a *launcher) stopLauncher() (string, []string, error) {
	if path, err := exec.LookPath("powershell.exe"); err == nil && path != "" {
		return path, []string{"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", filepath.Join(a.repoRoot, "scripts", "launch_full_stack_3_nodes.ps1"), "-Down"}, nil
	}
	if path, err := exec.LookPath("pwsh"); err == nil && path != "" {
		return path, []string{"-NoProfile", "-ExecutionPolicy", "Bypass", "-File", filepath.Join(a.repoRoot, "scripts", "launch_full_stack_3_nodes.ps1"), "-Down"}, nil
	}
	if path, err := exec.LookPath("bash"); err == nil && path != "" {
		return path, []string{filepath.Join(a.repoRoot, "scripts", "launch_full_stack_3_nodes.sh"), "--down"}, nil
	}
	return "", nil, errors.New("no supported shell found: install PowerShell or Bash")
}

func (r *commandRunner) snapshot() runnerSnapshot {
	r.mu.Lock()
	defer r.mu.Unlock()
	snapshot := runnerSnapshot{
		Running:   r.running,
		Label:     r.label,
		Command:   r.command,
		Output:    r.buffer.Lines(100),
		ExitError: r.exitError,
	}
	if !r.startedAt.IsZero() {
		snapshot.StartedAt = r.startedAt.Format(time.RFC3339)
	}
	if !r.finishedAt.IsZero() {
		snapshot.FinishedAt = r.finishedAt.Format(time.RFC3339)
	}
	return snapshot
}

func (r *commandRunner) run(dir, label, command string, args ...string) error {
	r.mu.Lock()
	if r.running {
		r.mu.Unlock()
		return errors.New("a launcher command is already running")
	}
	r.running = true
	r.label = label
	r.command = strings.Join(append([]string{command}, args...), " ")
	r.startedAt = time.Now()
	r.finishedAt = time.Time{}
	r.exitError = ""
	r.buffer = capturedOutput{}
	r.mu.Unlock()

	cmd := exec.Command(command, args...)
	cmd.Stdout = &r.buffer
	cmd.Stderr = &r.buffer
	cmd.Dir = dir

	if err := cmd.Start(); err != nil {
		r.finish(label, command, err)
		return err
	}

	go func() {
		err := cmd.Wait()
		if err != nil {
			r.finish(label, command, err)
			return
		}
		r.finish(label, command, nil)
	}()

	return nil
}

func (r *commandRunner) finish(label, command string, err error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.running = false
	r.label = label
	r.command = command
	r.finishedAt = time.Now()
	if err != nil {
		r.exitError = err.Error()
	} else {
		r.exitError = ""
	}
}

func (c *capturedOutput) Write(p []byte) (int, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.buf.Write(p)
}

func (c *capturedOutput) Lines(limit int) []string {
	c.mu.Lock()
	defer c.mu.Unlock()
	text := strings.ReplaceAll(c.buf.String(), "\r\n", "\n")
	text = strings.ReplaceAll(text, "\r", "\n")
	parts := strings.Split(text, "\n")
	trimmed := make([]string, 0, len(parts))
	for _, part := range parts {
		line := strings.TrimSpace(part)
		if line != "" {
			trimmed = append(trimmed, line)
		}
	}
	if len(trimmed) > limit {
		trimmed = trimmed[len(trimmed)-limit:]
	}
	return trimmed
}

func checkDocker() (bool, string) {
	if _, err := exec.LookPath("docker"); err != nil {
		return false, "docker is not installed"
	}
	cmd := exec.Command("docker", "info")
	if err := cmd.Run(); err != nil {
		return false, "docker daemon is not reachable"
	}
	return true, "docker daemon is reachable"
}

func inspectContainer(name, detail string) string {
	if _, err := exec.LookPath("docker"); err != nil {
		return "offline"
	}
	cmd := exec.Command("docker", "inspect", "-f", "{{.State.Status}}{{if .State.Health}}/{{.State.Health.Status}}{{end}}", name)
	output, err := cmd.Output()
	if err != nil {
		return "missing"
	}
	state := strings.TrimSpace(string(output))
	if state == "" {
		return "unknown"
	}
	if strings.Contains(state, "running/healthy") || strings.EqualFold(state, "healthy") {
		_ = detail
		return "healthy"
	}
	if strings.HasPrefix(state, "running") {
		return "running"
	}
	if strings.Contains(state, "exited") {
		return "stopped"
	}
	return state
}

func inspectHTTP(url, detail string) string {
	client := http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return "offline"
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		return "healthy"
	}
	_ = detail
	return fmt.Sprintf("http %d", resp.StatusCode)
}

func summarizeStack(services []serviceStatus, dockerOK bool) (string, string, string) {
	if !dockerOK {
		return "Offline", "bad", "Docker is unavailable, so the testnet cannot be launched or inspected."
	}
	online := 0
	for _, service := range services {
		if isServiceOnline(service.Status) {
			online++
		}
	}
	if online == len(services) {
		return "Online", "good", "Every tracked testnet service is reporting a live status."
	}
	if online >= 4 {
		return "Partial", "warn", "The stack is partially online. A few services may still be starting or stopped."
	}
	return "Stopped", "bad", "The stack is not currently visible on the local Docker host."
}

func isServiceOnline(status string) bool {
	return status == "healthy" || status == "running"
}

func findRepoRoot() (string, error) {
	if root, ok := probeRepoRoot(mustExecutableDir()); ok {
		return root, nil
	}
	if cwd, err := os.Getwd(); err == nil {
		if root, ok := probeRepoRoot(cwd); ok {
			return root, nil
		}
	}
	return "", errors.New("unable to locate the repository root")
}

func mustExecutableDir() string {
	exe, err := os.Executable()
	if err != nil {
		return "."
	}
	return filepath.Dir(exe)
}

func probeRepoRoot(start string) (string, bool) {
	current := start
	for {
		if current == "" || current == "." || current == string(filepath.Separator) {
			break
		}
		if fileExists(filepath.Join(current, "go.mod")) && fileExists(filepath.Join(current, "scripts", "launch_full_stack_3_nodes.ps1")) {
			return current, true
		}
		parent := filepath.Dir(current)
		if parent == current {
			break
		}
		current = parent
	}
	return "", false
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func openTargetURL(target string) (string, bool) {
	switch target {
	case "grafana":
		return "http://localhost:3000", true
	case "prometheus":
		return "http://localhost:9090", true
	case "orchestrator":
		return "https://localhost:8080", true
	case "readme":
		return "https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto/blob/main/README.md", true
	default:
		return "", false
	}
}

func dockerLabel(ok bool) string {
	if ok {
		return "Ready"
	}
	return "Blocked"
}

func utf16Ptr(value string) *uint16 {
	ptr, err := syscall.UTF16PtrFromString(value)
	if err != nil {
		return nil
	}
	return ptr
}

func mustGetModuleHandle() syscall.Handle {
	h, _, _ := procGetModuleHandleW.Call(0)
	return syscall.Handle(h)
}

func mustLoadCursor(id uintptr) syscall.Handle {
	h, _, _ := procLoadCursorW.Call(0, id)
	return syscall.Handle(h)
}

type wndClassEx struct {
	cbSize        uint32
	style         uint32
	lpfnWndProc   uintptr
	cbClsExtra    int32
	cbWndExtra    int32
	hInstance     syscall.Handle
	hIcon         syscall.Handle
	hCursor       syscall.Handle
	hbrBackground syscall.Handle
	lpszMenuName  *uint16
	lpszClassName *uint16
	hIconSm       syscall.Handle
}

type rect struct {
	Left   int32
	Top    int32
	Right  int32
	Bottom int32
}

type msg struct {
	Hwnd    uintptr
	Message uint32
	WParam  uintptr
	LParam  uintptr
	Time    uint32
	Pt      point
}

type point struct {
	X int32
	Y int32
}
