package test

// Failure-mode audit, area C (saved state and crashes). Each test starts the
// real pogi binary on a free port with a temp data dir, HOME in a temp dir and
// a dead DOCKER_HOST, so it touches neither ~/.pogi, port 7644 nor Docker.
// A test for an open mode fails on purpose; its message says what is wrong.

import (
	"bytes"
	"context"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/nrndev/pogi/internal/awstest"

	"github.com/nrndev/pogi"
)

var (
	binOnce sync.Once
	binPath string
	binDir  string
)

func TestMain(m *testing.M) {
	code := m.Run()
	if binDir != "" {
		os.RemoveAll(binDir)
	}
	os.Exit(code)
}

func pogiBin(t *testing.T) string {
	binOnce.Do(func() {
		binDir, _ = os.MkdirTemp("", "pogi-failmode-bin")
		binPath = filepath.Join(binDir, "pogi")
		out, err := exec.Command("go", append(goBuildArgs(), "-o", binPath, "../cmd/pogi")...).CombinedOutput()
		if err != nil {
			binPath = ""
			t.Logf("build: %v\n%s", err, out)
		}
	})
	if binPath == "" {
		t.Fatal("could not build pogi")
	}
	return binPath
}

type syncBuf struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (s *syncBuf) Write(p []byte) (int, error) { s.mu.Lock(); defer s.mu.Unlock(); return s.b.Write(p) }
func (s *syncBuf) String() string              { s.mu.Lock(); defer s.mu.Unlock(); return s.b.String() }

type proc struct {
	cmd  *exec.Cmd
	url  string
	out  *syncBuf
	done chan struct{}
	err  error
}

// launch starts pogi without waiting for it to be ready.
func launch(t *testing.T, dir, mode string) *proc {
	t.Helper()
	port := fmFreePort(t)
	if port == 7644 {
		t.Fatal("port 7644")
	}
	home := t.TempDir()
	cmd := exec.Command(pogiBin(t), "start", "--headless", "--quiet", "--port", strconv.Itoa(port),
		"--services", "sqs,s3", "--storage", mode, "--data-dir", dir,
		"--smtp-port", "-1", "--amqp-port", "-1", "--mqtt-port", "-1", "--transfer-port", "-1")
	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + home, "DOCKER_HOST=unix://" + filepath.Join(home, "no-docker.sock")}
	p := &proc{cmd: cmd, out: &syncBuf{}, done: make(chan struct{}), url: "http://127.0.0.1:" + strconv.Itoa(port)}
	cmd.Stdout, cmd.Stderr = p.out, p.out
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	go func() { p.err = cmd.Wait(); close(p.done) }()
	t.Cleanup(func() { p.kill() })
	return p
}

// startPogi launches pogi and waits until it answers.
func startStatePogi(t *testing.T, dir, mode string) *proc {
	t.Helper()
	p := launch(t, dir, mode)
	deadline := time.Now().Add(20 * time.Second)
	for time.Now().Before(deadline) {
		select {
		case <-p.done:
			t.Fatalf("pogi exited early: %v\n%s", p.err, p.out)
		default:
		}
		if r, err := http.Get(p.url + "/_pogi/api/info"); err == nil {
			r.Body.Close()
			if r.StatusCode == 200 {
				return p
			}
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("pogi did not become ready\n%s", p.out)
	return nil
}

func (p *proc) kill() {
	p.cmd.Process.Signal(syscall.SIGKILL)
	<-p.done
}

// stop is a clean shutdown (SIGTERM), which writes the state once more.
func (p *proc) stop(t *testing.T) {
	t.Helper()
	p.cmd.Process.Signal(syscall.SIGTERM)
	select {
	case <-p.done:
	case <-time.After(20 * time.Second):
		p.kill()
		t.Fatal("pogi did not stop on SIGTERM")
	}
}

func (p *proc) sqs(t *testing.T) *sqs.Client { return sqs.NewFromConfig(awstest.Config(t, p.url)) }

func queueURL(t *testing.T, c *sqs.Client, name string) string {
	t.Helper()
	r, err := c.GetQueueUrl(context.Background(), &sqs.GetQueueUrlInput{QueueName: aws.String(name)})
	if err != nil {
		t.Fatalf("queue %s: %v", name, err)
	}
	return *r.QueueUrl
}

func queues(t *testing.T, c *sqs.Client) []string {
	t.Helper()
	r, err := c.ListQueues(context.Background(), &sqs.ListQueuesInput{})
	if err != nil {
		t.Fatal(err)
	}
	return r.QueueUrls
}

func send(t *testing.T, c *sqs.Client, name, body string) {
	t.Helper()
	if _, err := c.SendMessage(context.Background(), &sqs.SendMessageInput{QueueUrl: aws.String(queueURL(t, c, name)), MessageBody: aws.String(body)}); err != nil {
		t.Fatal(err)
	}
}

func mkQueue(t *testing.T, c *sqs.Client, name string) {
	t.Helper()
	if _, err := c.CreateQueue(context.Background(), &sqs.CreateQueueInput{QueueName: aws.String(name)}); err != nil {
		t.Fatal(err)
	}
}

// TestCorruptStateFileIsKept starts with a truncated state file. Wanted: pogi
// refuses, or keeps the bad file (quarantine) so the data can be recovered.
func TestCorruptStateFileIsKept(t *testing.T) {
	setup := func(t *testing.T, mode string) string {
		dir := t.TempDir()
		p := startStatePogi(t, dir, mode)
		c := p.sqs(t)
		mkQueue(t, c, "precious")
		send(t, c, "precious", "hello")
		p.stop(t)
		return dir
	}
	// anyHolds reports whether some file under dir still has exactly want.
	anyHolds := func(dir string, want []byte) (found bool) {
		filepath.Walk(dir, func(p string, i os.FileInfo, err error) error {
			if err == nil && !i.IsDir() {
				if b, _ := os.ReadFile(p); bytes.Equal(b, want) {
					found = true
				}
			}
			return nil
		})
		return
	}
	t.Run("truncated file", func(t *testing.T) {
		dir := setup(t, "persistent")
		path := filepath.Join(dir, "state", "sqs.json")
		b, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		bad := b[:len(b)/2]
		os.WriteFile(path, bad, 0o600)
		p := launch(t, dir, "persistent")
		select {
		case <-p.done: // refused: fine, if clear
			t.Logf("refused: %v\n%s", p.err, p.out)
			if !anyHolds(dir, bad) {
				t.Fatal("pogi refused but changed the file")
			}
			return
		case <-time.After(6 * time.Second): // several flush ticks
		}
		t.Logf("pogi kept running. log:\n%s", p.out)
		p.stop(t)
		if after, _ := os.ReadFile(path); !bytes.Equal(after, bad) && !anyHolds(dir, bad) {
			t.Fatalf("pogi started empty, then overwrote the truncated state file (%d bytes) with %d bytes of empty state; no copy kept", len(bad), len(after))
		}
	})
	t.Run("corrupt legacy state.json refuses to start", func(t *testing.T) {
		dir := t.TempDir()
		bad := []byte(`{"version":1,"services":{"sqs":`)
		os.WriteFile(filepath.Join(dir, "state.json"), bad, 0o600)
		p := launch(t, dir, "persistent")
		select {
		case <-p.done:
		case <-time.After(6 * time.Second):
			t.Fatalf("pogi runs in memory while the user asked for saved state:\n%s", p.out)
		}
		if p.err == nil || !strings.Contains(p.out.String(), "state.json") {
			t.Fatalf("want exit 1 with a message naming state.json, got %v:\n%s", p.err, p.out)
		}
		if after, _ := os.ReadFile(filepath.Join(dir, "state.json")); !bytes.Equal(after, bad) {
			t.Fatal("the legacy file was changed")
		}
	})
}

// TestSecondPogiOnOneFolderRefuses runs two pogis on one data dir. Wanted: the
// second refuses to start (a lock).
func TestSecondPogiOnOneFolderRefuses(t *testing.T) {
	dir := t.TempDir()
	a := startStatePogi(t, dir, "persistent")
	mkQueue(t, a.sqs(t), "from-a")
	time.Sleep(1500 * time.Millisecond)
	b := launch(t, dir, "persistent")
	select {
	case <-b.done:
		if b.err == nil || !strings.Contains(b.out.String(), "another pogi (pid ") {
			t.Fatalf("want exit 1 with 'another pogi (pid N) is using ...', got %v:\n%s", b.err, b.out)
		}
		a.stop(t)
		c := startStatePogi(t, dir, "persistent") // a stopped pogi leaves no lock behind
		c.kill()
		return
	case <-time.After(4 * time.Second):
	}
	mkQueue(t, b.sqs(t), "from-b")
	time.Sleep(2500 * time.Millisecond)
	a.stop(t)
	b.stop(t)
	c := startStatePogi(t, dir, "persistent")
	defer c.kill()
	t.Fatalf("both pogis ran on one data dir with no lock and no warning; after both stopped the folder holds queues %v (log of second: %s)",
		queues(t, c.sqs(t)), b.out)
}

// TestUnwritableStateIsNotSilent makes the state folder read-only at start and
// while pogi runs.
func TestUnwritableStateIsNotSilent(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("root ignores permissions")
	}
	t.Run("at start", func(t *testing.T) {
		dir := t.TempDir()
		os.Chmod(dir, 0o500)
		defer os.Chmod(dir, 0o700)
		p := launch(t, dir, "persistent")
		select {
		case <-p.done:
			if p.err == nil || !strings.Contains(p.out.String(), "--data-dir") {
				t.Fatalf("want exit 1 with a plain message, got %v:\n%s", p.err, p.out)
			}
			return
		case <-time.After(5 * time.Second):
		}
		t.Logf("kept running, log:\n%s", p.out)
		out := p.out.String()
		if !strings.Contains(out, "could not load saved state") && !strings.Contains(out, "permission") {
			t.Fatalf("pogi runs without saving and says nothing:\n%s", out)
		}
		// open if the notice exists but never says state will NOT be saved
		if !strings.Contains(out, "not be saved") && !strings.Contains(out, "read-only") {
			t.Fatalf("log mentions a load problem but never says state will not be saved:\n%s", out)
		}
	})
	t.Run("while running", func(t *testing.T) {
		dir := t.TempDir()
		p := startStatePogi(t, dir, "persistent")
		c := p.sqs(t)
		mkQueue(t, c, "one")
		time.Sleep(1500 * time.Millisecond)
		os.Chmod(filepath.Join(dir, "state"), 0o500)
		defer os.Chmod(filepath.Join(dir, "state"), 0o700)
		mkQueue(t, c, "two") // the request still succeeds: is the failure visible anywhere?
		time.Sleep(3 * time.Second)
		log := p.out.String()
		t.Logf("log:\n%s", log)
		repeated := strings.Count(log, "save state")
		r, _ := http.Get(p.url + "/_pogi/api/info")
		body := &bytes.Buffer{}
		body.ReadFrom(r.Body)
		r.Body.Close()
		t.Logf("info: %s", body)
		if repeated != 1 {
			t.Fatalf("a failing save must be logged once, not %d times", repeated)
		}
		if info := body.String(); !strings.Contains(info, "can't save its state") {
			t.Fatalf("save failed %d times (log only); the admin API and console show healthy state, so a user is not warned that new state is not saved", repeated)
		}
		os.Chmod(filepath.Join(dir, "state"), 0o700)
		time.Sleep(2500 * time.Millisecond)
		p.stop(t)
		q := startStatePogi(t, dir, "persistent")
		defer q.kill()
		if len(queues(t, q.sqs(t))) != 2 {
			t.Fatalf("after the folder was writable again the state did not catch up: %v", queues(t, q.sqs(t)))
		}
	})
}

// Closing a pogi twice is safe: tests stop a server early and its cleanup closes it again
// (a service's second close used to panic: "close of closed channel").
func TestCloseTwiceIsSafe(t *testing.T) {
	s := pogi.Start(t)
	s.Hub.Close()
	s.Hub.Close()
}
