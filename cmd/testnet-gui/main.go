//go:build !windows

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
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"
)

const defaultListenAddr = "127.0.0.1:49281"

var dashboardTemplate = template.Must(template.New("dashboard").Parse(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <title>Sovereign Mohawk Testnet Control</title>
  <style>
    :root {
      color-scheme: dark;
      --bg: #07111f;
      --bg-2: #0b1d30;
      --panel: rgba(10, 21, 38, 0.86);
      --panel-strong: rgba(13, 27, 49, 0.96);
      --line: rgba(148, 163, 184, 0.18);
      --text: #e5eefb;
      --muted: #98a9c4;
      --accent: #56e0c8;
      --accent-2: #f7b955;
      --good: #55d68a;
      --warn: #f2c36d;
      --bad: #f06a74;
      --shadow: 0 22px 60px rgba(0, 0, 0, 0.38);
      --radius: 22px;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      font-family: "Segoe UI Variable", "Segoe UI", "Trebuchet MS", sans-serif;
      color: var(--text);
      background:
        radial-gradient(circle at top left, rgba(86, 224, 200, 0.18), transparent 30%),
        radial-gradient(circle at 85% 15%, rgba(247, 185, 85, 0.17), transparent 26%),
        linear-gradient(180deg, var(--bg) 0%, #091423 52%, #06101d 100%);
      min-height: 100vh;
    }

    .shell {
      max-width: 1360px;
      margin: 0 auto;
      padding: 28px;
    }

    .hero {
      display: grid;
      grid-template-columns: 1.4fr 1fr;
      gap: 18px;
      margin-bottom: 18px;
    }

    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      box-shadow: var(--shadow);
      backdrop-filter: blur(16px);
    }

    .hero-copy {
      padding: 28px;
      position: relative;
      overflow: hidden;
    }

    .hero-copy::after {
      content: "";
      position: absolute;
      inset: auto -120px -120px auto;
      width: 280px;
      height: 280px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(86, 224, 200, 0.18), transparent 64%);
      pointer-events: none;
    }

    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 8px 12px;
      border-radius: 999px;
      background: rgba(86, 224, 200, 0.12);
      color: #bdf9ef;
      border: 1px solid rgba(86, 224, 200, 0.18);
      font-size: 12px;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      margin-bottom: 18px;
    }

    .title {
      margin: 0 0 10px;
      font-size: clamp(32px, 4vw, 56px);
      line-height: 1.02;
      letter-spacing: -0.04em;
    }

    .gradient-text {
      background: linear-gradient(135deg, var(--accent) 0%, #87a8ff 54%, var(--accent-2) 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }

    .lede {
      margin: 0;
      max-width: 60ch;
      color: var(--muted);
      font-size: 16px;
      line-height: 1.65;
    }

    .status-strip {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      margin-top: 18px;
    }

    .pill {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 8px 12px;
      border-radius: 999px;
      font-size: 13px;
      border: 1px solid var(--line);
      background: rgba(255, 255, 255, 0.04);
    }

    .dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: var(--muted);
      box-shadow: 0 0 0 4px rgba(255, 255, 255, 0.04);
    }

    .dot.good { background: var(--good); }
    .dot.warn { background: var(--warn); }
    .dot.bad { background: var(--bad); }

    .sidebar {
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    .sidebar h2,
    .section h2 {
      margin: 0;
      font-size: 18px;
      letter-spacing: -0.02em;
    }

    .actions {
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }

    .button {
      appearance: none;
      border: none;
      border-radius: 16px;
      padding: 14px 16px;
      color: #08111d;
      font-weight: 700;
      font-size: 14px;
      cursor: pointer;
      background: linear-gradient(135deg, var(--accent) 0%, #91fff0 100%);
      box-shadow: 0 14px 28px rgba(86, 224, 200, 0.16);
      transition: transform 140ms ease, box-shadow 140ms ease, opacity 140ms ease;
      text-decoration: none;
      text-align: center;
    }

    .button.secondary {
      color: var(--text);
      background: linear-gradient(135deg, rgba(123, 143, 173, 0.18) 0%, rgba(86, 224, 200, 0.14) 100%);
      border: 1px solid var(--line);
      box-shadow: none;
    }

    .button.critical {
      color: #fff;
      background: linear-gradient(135deg, #e96a73 0%, #f7b955 140%);
      box-shadow: 0 14px 28px rgba(233, 106, 115, 0.16);
    }

    .button:hover { transform: translateY(-1px); }
    .button:disabled { opacity: 0.55; cursor: not-allowed; transform: none; }

    .section {
      margin-top: 18px;
      display: grid;
      grid-template-columns: 1.25fr 0.75fr;
      gap: 18px;
    }

    .services,
    .activity {
      padding: 22px;
    }

    .grid-list {
      margin-top: 16px;
      display: grid;
      gap: 12px;
    }

    .service-row {
      padding: 14px 16px;
      border-radius: 16px;
      border: 1px solid var(--line);
      background: rgba(255, 255, 255, 0.03);
      display: flex;
      justify-content: space-between;
      gap: 16px;
      align-items: center;
    }

    .service-name { font-weight: 700; }
    .service-desc { color: var(--muted); font-size: 13px; margin-top: 4px; }

    .tag {
      padding: 7px 10px;
      border-radius: 999px;
      font-size: 12px;
      border: 1px solid var(--line);
      white-space: nowrap;
    }

    .tag.good { background: rgba(85, 214, 138, 0.12); color: #b8f3ce; }
    .tag.warn { background: rgba(242, 195, 109, 0.12); color: #ffe3a1; }
    .tag.bad { background: rgba(240, 106, 116, 0.12); color: #ffb2b8; }
    .tag.neutral { color: var(--muted); }

    .stat-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 14px;
    }

    .stat {
      padding: 18px;
      border-radius: 18px;
      border: 1px solid var(--line);
      background: var(--panel-strong);
      min-height: 126px;
    }

    .stat-label {
      color: var(--muted);
      font-size: 12px;
      letter-spacing: 0.09em;
      text-transform: uppercase;
      margin-bottom: 12px;
    }

    .stat-value {
      font-size: 30px;
      font-weight: 700;
      letter-spacing: -0.03em;
      margin-bottom: 8px;
    }

    .stat-subtle {
      color: var(--muted);
      font-size: 13px;
      line-height: 1.45;
    }

    .log {
      background: rgba(0, 0, 0, 0.24);
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 16px;
      min-height: 360px;
      max-height: 640px;
      overflow: auto;
      font-family: Consolas, "Cascadia Mono", "SFMono-Regular", monospace;
      font-size: 12px;
      line-height: 1.6;
      white-space: pre-wrap;
    }

    .footer-note {
      color: var(--muted);
      font-size: 13px;
      line-height: 1.5;
    }

    .error {
      margin-top: 8px;
      color: #ffbcc0;
      font-size: 13px;
      min-height: 20px;
    }

    @media (max-width: 1100px) {
      .hero,
      .section {
        grid-template-columns: 1fr;
      }

      .stat-grid {
        grid-template-columns: repeat(2, 1fr);
      }
    }

    @media (max-width: 700px) {
      .shell { padding: 16px; }
      .actions,
      .stat-grid {
        grid-template-columns: 1fr;
      }

      .service-row {
        flex-direction: column;
        align-items: flex-start;
      }
    }
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <article class="panel hero-copy">
        <div class="eyebrow"><span class="dot" id="stackDot"></span><span id="stackState">Loading testnet status</span></div>
        <h1 class="title">Sovereign <span class="gradient-text">Mohawk</span><br>Testnet Control</h1>
        <p class="lede">
          A Windows-first launcher and status console for the local genesis testnet stack. Start the stack, stop it cleanly,
          and watch the Docker, Prometheus, Grafana, and node-agent footprint from one place.
        </p>
        <div class="status-strip" id="statusStrip"></div>
      </article>

      <aside class="panel sidebar">
        <div>
          <h2>Actions</h2>
          <div class="footer-note">The launcher uses the checked-in PowerShell script on Windows and falls back to Bash if available.</div>
        </div>
        <div class="actions">
          <button class="button" id="startFullStack">Start Full Stack</button>
          <button class="button secondary" id="startGenesis">Start Genesis</button>
          <button class="button critical" id="stopStack">Stop Stack</button>
          <button class="button secondary" id="refreshNow">Refresh Status</button>
        </div>
        <div class="actions">
          <a class="button secondary" href="/open/grafana" target="_blank" rel="noreferrer">Open Grafana</a>
          <a class="button secondary" href="/open/prometheus" target="_blank" rel="noreferrer">Open Prometheus</a>
          <a class="button secondary" href="/open/orchestrator" target="_blank" rel="noreferrer">Open Orchestrator</a>
          <a class="button secondary" href="/open/readme" target="_blank" rel="noreferrer">Open README</a>
        </div>
        <div class="error" id="errorBox"></div>
      </aside>
    </section>

    <section class="stat-grid" id="statsGrid"></section>

    <section class="section">
      <article class="panel services">
        <h2>Service Map</h2>
        <div class="grid-list" id="serviceList"></div>
      </article>

      <article class="panel activity">
        <h2>Launcher Log</h2>
        <div class="footer-note" id="commandSummary">No command running.</div>
        <div class="log" id="logOutput"></div>
      </article>
    </section>
  </main>

  <script>
    async function fetchStatus() {
      const response = await fetch('/api/status', { cache: 'no-store' });
      if (!response.ok) {
        throw new Error('status request failed: ' + response.status);
      }
      return await response.json();
    }

    function escapeHtml(value) {
      return String(value)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
    }

    function renderBadge(kind, text) {
      return '<span class="pill"><span class="dot ' + kind + '"></span>' + escapeHtml(text) + '</span>';
    }

    function renderStat(stat) {
      return '<article class="stat">' +
        '<div class="stat-label">' + escapeHtml(stat.label) + '</div>' +
        '<div class="stat-value">' + escapeHtml(stat.value) + '</div>' +
        '<div class="stat-subtle">' + escapeHtml(stat.subtext) + '</div>' +
        '</article>';
    }

    function serviceTagClass(status) {
      if (status === 'healthy' || status === 'running' || status === 'online') return 'good';
      if (status === 'starting' || status === 'partial') return 'warn';
      if (status === 'stopped' || status === 'offline' || status === 'missing' || status === 'error') return 'bad';
      return 'neutral';
    }

    function renderService(service) {
      const tagClass = serviceTagClass(service.status);
      const detail = service.detail ? '<div class="service-desc">' + escapeHtml(service.detail) + '</div>' : '';
      return '<div class="service-row">' +
        '<div>' +
          '<div class="service-name">' + escapeHtml(service.name) + '</div>' +
          detail +
        '</div>' +
        '<div class="tag ' + tagClass + '">' + escapeHtml(service.status) + '</div>' +
      '</div>';
    }

    async function mutate(path) {
      const response = await fetch(path, { method: 'POST' });
      const payload = await response.json().catch(() => ({}));
      if (!response.ok) {
        throw new Error(payload.error || 'request failed: ' + response.status);
      }
      return payload;
    }

    function setError(message) {
      document.getElementById('errorBox').textContent = message || '';
    }

    function setBusy(isBusy) {
      ['startFullStack', 'startGenesis', 'stopStack', 'refreshNow'].forEach((id) => {
        document.getElementById(id).disabled = isBusy;
      });
    }

    function renderStatus(status) {
      document.getElementById('stackState').textContent = status.stack_state;
      const stackDot = document.getElementById('stackDot');
      stackDot.className = 'dot ' + status.stack_state_kind;

      document.getElementById('statusStrip').innerHTML = [
        renderBadge(status.docker_ok ? 'good' : 'bad', status.docker_ok ? 'Docker ready' : 'Docker unavailable'),
        renderBadge(status.runner.running ? 'warn' : 'good', status.runner.running ? ('Command: ' + status.runner.label) : 'Launcher idle'),
        renderBadge(status.stack_state_kind, status.stack_state),
        renderBadge('neutral', status.online_services + '/' + status.total_services + ' services online'),
      ].join('');

      document.getElementById('statsGrid').innerHTML = [
        renderStat({ label: 'Stack health', value: status.stack_state, subtext: status.stack_summary }),
        renderStat({ label: 'Docker', value: status.docker_ok ? 'Ready' : 'Blocked', subtext: status.docker_detail || 'Docker is the only hard dependency for the stack.' }),
        renderStat({ label: 'Online services', value: status.online_services + '/' + status.total_services, subtext: 'Node agents online: ' + status.online_nodes + '/' + status.expected_nodes }),
        renderStat({ label: 'Active shell', value: status.shell_label, subtext: status.repo_root }),
      ].join('');

      document.getElementById('serviceList').innerHTML = status.services.map(renderService).join('');

      const commandSummary = document.getElementById('commandSummary');
      if (status.runner.running) {
        commandSummary.textContent = status.runner.label + ' started ' + status.runner.started_at + ' from ' + status.runner.command;
      } else if (status.runner.finished_at) {
        commandSummary.textContent = status.runner.label + ' finished ' + status.runner.finished_at + (status.runner.exit_error ? ': ' + status.runner.exit_error : '');
      } else {
        commandSummary.textContent = 'No command running.';
      }

      document.getElementById('logOutput').textContent = status.runner.output.join('\n');
    }

    async function refresh() {
      setError('');
      try {
        const status = await fetchStatus();
        renderStatus(status);
      } catch (err) {
        setError(err.message || String(err));
      }
    }

    async function action(path) {
      setError('');
      setBusy(true);
      try {
        await mutate(path);
      } catch (err) {
        setError(err.message || String(err));
      } finally {
        await refresh();
        setBusy(false);
      }
    }

    document.getElementById('startFullStack').addEventListener('click', () => action('/api/start/full-stack'));
    document.getElementById('startGenesis').addEventListener('click', () => action('/api/start/genesis'));
    document.getElementById('stopStack').addEventListener('click', () => action('/api/stop'));
    document.getElementById('refreshNow').addEventListener('click', refresh);

    refresh();
    setInterval(refresh, 3000);
  </script>
</body>
</html>`))

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

func main() {
	repoRoot, err := findRepoRoot()
	if err != nil {
		log.Fatal(err)
	}

	addr := os.Getenv("MOHAWK_TESTNET_GUI_ADDR")
	if addr == "" {
		addr = defaultListenAddr
	}

	app := &launcher{
		repoRoot: repoRoot,
		runner:   &commandRunner{},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", app.handleIndex)
	mux.HandleFunc("/api/status", app.handleStatus)
	mux.HandleFunc("/api/start/full-stack", app.handleStartFullStack)
	mux.HandleFunc("/api/start/genesis", app.handleStartGenesis)
	mux.HandleFunc("/api/stop", app.handleStop)
	mux.HandleFunc("/open/", app.handleOpen)

	server := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	listener, err := net.Listen("tcp", addr)
	if err != nil {
		log.Fatal(err)
	}

	url := "http://" + listener.Addr().String()
	log.Printf("testnet GUI listening on %s", url)

	go func() {
		if os.Getenv("MOHAWK_TESTNET_GUI_NO_BROWSER") == "1" {
			return
		}
		if err := openBrowser(url); err != nil {
			log.Printf("browser launch skipped: %v", err)
		}
	}()

	log.Fatal(server.Serve(listener))
}

func (a *launcher) handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_ = dashboardTemplate.Execute(w, nil)
}

func (a *launcher) handleStatus(w http.ResponseWriter, r *http.Request) {
	status := a.snapshotStatus()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(status)
}

func (a *launcher) handleStartFullStack(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := a.startFullStack(); err != nil {
		writeJSONError(w, err, http.StatusBadRequest)
		return
	}
	writeJSONOK(w)
}

func (a *launcher) handleStartGenesis(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := a.startGenesis(); err != nil {
		writeJSONError(w, err, http.StatusBadRequest)
		return
	}
	writeJSONOK(w)
}

func (a *launcher) handleStop(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if err := a.stopStack(); err != nil {
		writeJSONError(w, err, http.StatusBadRequest)
		return
	}
	writeJSONOK(w)
}

func (a *launcher) handleOpen(w http.ResponseWriter, r *http.Request) {
	target := strings.TrimPrefix(r.URL.Path, "/open/")
	url, ok := openTargetURL(target)
	if !ok {
		http.NotFound(w, r)
		return
	}
	http.Redirect(w, r, url, http.StatusFound)
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
	for current := start; current != "" && current != "." && current != string(filepath.Separator); {
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

func openBrowser(url string) error {
	switch runtime.GOOS {
	case "linux":
		if path, err := exec.LookPath("xdg-open"); err == nil && path != "" {
			return exec.Command(path, url).Start()
		}
	case "darwin":
		if path, err := exec.LookPath("open"); err == nil && path != "" {
			return exec.Command(path, url).Start()
		}
	}
	return errors.New("browser launch is not available")
}

func writeJSONOK(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"ok": true})
}

func writeJSONError(w http.ResponseWriter, err error, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"ok": false, "error": err.Error()})
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
