package main

// A busy port: the port is busy when pogi starts. The binary is built and run here on
// ports this test binds itself (never 7644), with no container engine (DOCKER_HOST points at a
// closed port), so its startup sweep cannot touch any real container.

import (
	"bytes"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/nrndev/pogi/internal/core"
)

type rtBuf struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *rtBuf) Write(p []byte) (int, error) { s.mu.Lock(); defer s.mu.Unlock(); return s.b.Write(p) }
func (s *rtBuf) String() string              { s.mu.Lock(); defer s.mu.Unlock(); return s.b.String() }

func rtBusyPort(t *testing.T) (port int) {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })
	return ln.Addr().(*net.TCPAddr).Port
}

func rtFreePort(t *testing.T) int {
	t.Helper()
	ln, _ := net.Listen("tcp", "127.0.0.1:0")
	defer ln.Close()
	return ln.Addr().(*net.TCPAddr).Port
}

func rtBuildPogi(t *testing.T) string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "pogi")
	if out, err := exec.Command("go", append(goBuildArgs(), "-o", bin, ".")...).CombinedOutput(); err != nil {
		t.Fatalf("build: %v\n%s", err, out)
	}
	return bin
}

func rtPogiCmd(t *testing.T, bin string, args ...string) (*exec.Cmd, *rtBuf) {
	t.Helper()
	all := append([]string{"start", "--headless", "--data-dir", t.TempDir(), "--smtp-port", "-1", "--mqtt-port", "-1", "--amqp-port", "-1", "--transfer-port", "-1"}, args...)
	cmd := exec.Command(bin, all...)
	cmd.Env = append(os.Environ(), "DOCKER_HOST=tcp://127.0.0.1:"+strconv.Itoa(rtFreePort(t)), "POGI_PORT=", "POGI_CONFIG=")
	out := &rtBuf{}
	cmd.Stdout, cmd.Stderr = out, out
	return cmd, out
}

// the main port is busy. pogi must exit nonzero, quickly, with a message that names the port.
func TestMainPortBusyIsPlain(t *testing.T) {
	bin := rtBuildPogi(t)
	port := rtBusyPort(t)
	cmd, out := rtPogiCmd(t, bin, "--port", strconv.Itoa(port))
	done := make(chan error, 1)
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		code := cmd.ProcessState.ExitCode()
		t.Logf("exit code %d (%v); output:\n%s", code, err, out)
		if code == 0 {
			t.Error("exit code 0 although pogi could not listen")
		}
		if !strings.Contains(out.String(), strconv.Itoa(port)) {
			t.Errorf("the message does not name the port: %q", out)
		}
		if strings.Contains(out.String(), "bind: address already in use") && !strings.Contains(strings.ToLower(out.String()), "already") {
			t.Error("raw bind error only")
		}
		if !strings.Contains(out.String(), "--port") && !strings.Contains(out.String(), "another") {
			t.Errorf("the message gives no hint (another pogi running? use --port): %q", strings.TrimSpace(out.String()))
		}
	case <-time.After(15 * time.Second):
		cmd.Process.Kill()
		t.Fatalf("pogi did not exit within 15s with its port busy; output:\n%s", out)
	}
}

// an extra port (here the SMTP port) is busy. pogi starts without it, and the banner says so next
// to smtp, once: no log line repeats it unless --debug. /_pogi/api/info lists it as a problem, which
// the TUI, the console and pogi status show.
func TestExtraPortBusyShowsInBanner(t *testing.T) {
	bin := rtBuildPogi(t)
	smtp, port := rtBusyPort(t), rtFreePort(t)
	cmd, out := rtPogiCmd(t, bin, "--port", strconv.Itoa(port), "--smtp-port", strconv.Itoa(smtp))
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cmd.Process.Kill(); cmd.Wait() })
	for end := time.Now().Add(20 * time.Second); !strings.Contains(out.String(), "Ready."); time.Sleep(100 * time.Millisecond) {
		if time.Now().After(end) {
			t.Fatalf("not ready: %s", out)
		}
	}
	t.Logf("output:\n%s", out)
	found := false
	for _, l := range strings.Split(out.String(), "\n") {
		if strings.HasPrefix(l, "  smtp") && strings.Contains(l, strconv.Itoa(smtp)) && strings.Contains(l, "in use") {
			found = true
		}
	}
	if !found {
		t.Errorf("the banner does not show the busy SMTP port %d next to smtp:\n%s", smtp, out)
	}
	var st core.Status
	if err := api("http://127.0.0.1:"+strconv.Itoa(port), "GET", "/_pogi/api/info", nil, &st); err != nil {
		t.Fatal(err)
	}
	want := "smtp: port " + strconv.Itoa(smtp) + " is in use"
	if len(st.Problems) != 1 || st.Problems[0].Kind != "port" || !strings.HasPrefix(st.Problems[0].Text, want) {
		t.Errorf("problems = %+v, want one port problem starting %q", st.Problems, want)
	}
	if strings.Contains(out.String(), "port unavailable") {
		t.Errorf("a log line repeats what the banner says:\n%s", out)
	}
}

// Ctrl-C says at once that pogi is stopping, and a second Ctrl-C quits without waiting for the
// shutdown. An open long-poll request holds the shutdown for its 5-second limit.
func TestSecondInterruptQuits(t *testing.T) {
	bin := rtBuildPogi(t)
	port := rtFreePort(t)
	cmd, out := rtPogiCmd(t, bin, "--port", strconv.Itoa(port), "--quiet")
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { cmd.Process.Kill(); cmd.Wait() })
	waitFor := func(s string, d time.Duration) {
		t.Helper()
		for end := time.Now().Add(d); !strings.Contains(out.String(), s); time.Sleep(20 * time.Millisecond) {
			if time.Now().After(end) {
				t.Fatalf("no %q after %s:\n%s", s, d, out)
			}
		}
	}
	waitFor("Ready.", 20*time.Second)
	go http.Get("http://127.0.0.1:" + strconv.Itoa(port) + "/_pogi/api/requests?after=999999&wait=25")
	time.Sleep(200 * time.Millisecond) // the long poll is open
	cmd.Process.Signal(os.Interrupt)
	waitFor("Stopping… (press Ctrl-C again to quit now)", 2*time.Second)
	cmd.Process.Signal(os.Interrupt)
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatalf("pogi kept stopping after a second Ctrl-C:\n%s", out)
	}
}
