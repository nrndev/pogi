package test

// Security regression tests: cross-site posts, rebound hosts, and secrets in the request log.

import (
	"bytes"
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/nrndev/pogi"
	"github.com/nrndev/pogi/internal/awstest"
)

const fmBrowser = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15"

type fmRes struct {
	Code int
	Body string
	H    http.Header
}

// fmDo sends one request. hdr is name, value pairs; "Host" sets the Host header.
func fmDo(t testing.TB, method, u, body string, hdr ...string) fmRes {
	t.Helper()
	req, err := http.NewRequest(method, u, strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	fmApply(req, hdr)
	return fmSend(t, req)
}

func fmApply(req *http.Request, hdr []string) {
	for i := 0; i+1 < len(hdr); i += 2 {
		if strings.EqualFold(hdr[i], "Host") {
			req.Host = hdr[i+1]
			continue
		}
		req.Header.Set(hdr[i], hdr[i+1])
	}
}

func fmSend(t testing.TB, req *http.Request) fmRes {
	t.Helper()
	c := &http.Client{Timeout: 30 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	res, err := c.Do(req)
	if err != nil {
		t.Fatalf("%s %s: %v", req.Method, req.URL, err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	return fmRes{res.StatusCode, string(b), res.Header}
}

// fmSigned sends a SigV4-signed request (no browser headers), the way an SDK would.
func fmSigned(t testing.TB, base, service, method, path, ctype, target, body string, hdr ...string) fmRes {
	t.Helper()
	req, err := http.NewRequest(method, base+path, strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	if ctype != "" {
		req.Header.Set("Content-Type", ctype)
	}
	if target != "" {
		req.Header.Set("X-Amz-Target", target)
	}
	fmApply(req, hdr)
	awstest.Sign(t, req, service)
	return fmSend(t, req)
}

const (
	fmForm = "application/x-www-form-urlencoded"
	fmJ11  = "application/x-amz-json-1.1"
)

func fmQueues(t testing.TB, base string) []string {
	t.Helper()
	out, err := sqs.NewFromConfig(awstest.Config(t, base)).ListQueues(context.Background(), &sqs.ListQueuesInput{})
	if err != nil {
		t.Fatal(err)
	}
	return out.QueueUrls
}

func fmHasQueue(t testing.TB, base, name string) bool {
	for _, u := range fmQueues(t, base) {
		if strings.HasSuffix(u, "/"+name) {
			return true
		}
	}
	return false
}

// ---- S1: another website posts to the console ----

func TestMCPAndConsoleRefuseOtherSites(t *testing.T) {
	srv := pogi.Start(t)
	ctx := context.Background()
	q := sqs.NewFromConfig(awstest.Config(t, srv.URL))
	reset := func() {
		srv.Reset()
		if _, err := q.CreateQueue(ctx, &sqs.CreateQueueInput{QueueName: aws.String("keep")}); err != nil {
			t.Fatal(err)
		}
	}
	mcp := `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"reset","arguments":{}}}`
	targets := []struct {
		name, path, body, ctype string
		extra                   []string
		ran                     func() bool // did the attack change state?
	}{
		{"console reset form", "/_pogi/reset", "service=", fmForm, nil, func() bool { return !fmHasQueue(t, srv.URL, "keep") }},
		{"admin API reset", "/_pogi/api/reset", "", fmForm, nil, func() bool { return !fmHasQueue(t, srv.URL, "keep") }},
		{"moto-compat reset", "/moto-api/reset", "", fmForm, nil, func() bool { return !fmHasQueue(t, srv.URL, "keep") }},
		{"console create form", "/_pogi/new/sqs/CreateQueue", "QueueName=evil", fmForm, nil, func() bool { return fmHasQueue(t, srv.URL, "evil") }},
		{"MCP reset tool", "/_pogi/mcp", mcp, "application/json", []string{"Accept", "application/json, text/event-stream"}, func() bool { return !fmHasQueue(t, srv.URL, "keep") }},
	}
	attacks := []struct {
		name    string
		hdr     []string
		blocked bool // what a safe pogi does
	}{
		{"evil Origin + cross-site", []string{"Origin", "https://evil.example", "Sec-Fetch-Site", "cross-site", "Sec-Fetch-Mode", "navigate", "User-Agent", fmBrowser}, true},
		{"evil Origin only", []string{"Origin", "https://evil.example"}, true},
		{"cross-site only, no Origin", []string{"Sec-Fetch-Site", "cross-site", "User-Agent", fmBrowser}, true},
		{"Origin null (sandboxed frame)", []string{"Origin", "null", "Sec-Fetch-Site", "cross-site"}, true},
		{"other local app, localhost:3000", []string{"Origin", "http://localhost:3000", "Sec-Fetch-Site", "same-site", "User-Agent", fmBrowser}, true},
		{"browser, no Fetch headers or Origin", []string{"User-Agent", fmBrowser}, false}, // very old browsers; cannot be told from a user
		{"curl, no browser headers", nil, false},
	}
	for _, tg := range targets {
		// control: the call really works, so a "blocked" result below means something
		reset()
		r := fmDo(t, "POST", srv.URL+tg.path, tg.body, append([]string{"Content-Type", tg.ctype}, tg.extra...)...)
		if !tg.ran() {
			t.Fatalf("S1 control %s: curl did not change state (HTTP %d %.100s)", tg.name, r.Code, r.Body)
		}
		for _, a := range attacks {
			reset()
			r := fmDo(t, "POST", srv.URL+tg.path, tg.body, append(append([]string{"Content-Type", tg.ctype}, tg.extra...), a.hdr...)...)
			ran := tg.ran()
			t.Logf("S1 %-20s | %-36s -> HTTP %d, state changed: %v", tg.name, a.name, r.Code, ran)
			if a.blocked && ran {
				t.Errorf("S1 OPEN: %s from %q changed state (HTTP %d)", tg.name, a.name, r.Code)
			}
		}
	}
}

// ---- S3: DNS rebinding ----

func TestRebindHostsAreRefused(t *testing.T) {
	srv := pogi.Start(t)
	port := srv.URL[strings.LastIndexByte(srv.URL, ':')+1:]
	paths := []struct{ method, path, body, ctype string }{
		{"GET", "/", "", ""},
		{"GET", "/_pogi/", "", ""},
		{"GET", "/_pogi/api/requests", "", ""},
		{"GET", "/_pogi/api/resources", "", ""},
		{"GET", "/_localstack/health", "", ""},
		{"POST", "/_pogi/api/reset", "", fmForm},
		{"POST", "/", "Action=ListQueues&Version=2012-11-05", fmForm},
		{"POST", "/_pogi/mcp", `{"jsonrpc":"2.0","id":1,"method":"tools/list"}`, "application/json"},
	}
	// a rebound page: the browser sends Host: <attacker name>, a Mozilla User-Agent, and same-origin Fetch headers
	hosts := []string{"evil.example", "evil.example:" + port, "localhost.evil.example", "127.0.0.1.nip.io", "evil.example.", "evil.xlocalhost", "evil.example.localhost.evil.example", "2130706433.evil.example"}
	for _, h := range hosts {
		for _, p := range paths {
			r := fmDo(t, p.method, srv.URL+p.path, p.body, "Host", h, "User-Agent", fmBrowser, "Sec-Fetch-Site", "same-origin", "Sec-Fetch-Mode", "cors",
				"Content-Type", p.ctype, "Accept", "application/json, text/event-stream")
			if r.Code != 403 {
				t.Errorf("S3 OPEN: Host %q %s %s answered HTTP %d: %.80s", h, p.method, p.path, r.Code, r.Body)
			}
		}
	}
	// the same names without browser signs (curl, SDKs) pass: that is how containers and `curl -H Host:` work
	r := fmDo(t, "GET", srv.URL+"/_pogi/api/info", "", "Host", "evil.example")
	t.Logf("S3 non-browser client with Host: evil.example -> HTTP %d (expected: allowed; a page cannot drop its Mozilla User-Agent)", r.Code)
	// the real names work
	for _, h := range []string{"localhost:" + port, "127.0.0.1:" + port, "[::1]:" + port, "foo.localhost:" + port} {
		if r := fmDo(t, "GET", srv.URL+"/_pogi/api/info", "", "Host", h, "User-Agent", fmBrowser, "Sec-Fetch-Site", "same-origin"); r.Code != 200 {
			t.Errorf("S3 control: Host %q = HTTP %d", h, r.Code)
		}
	}
	// the extra Azure Storage port is behind the same gate
	if bp := srv.Ports["azblob"]; bp != "" {
		r := fmDo(t, "PUT", bp+"/devstoreaccount1/rebind?restype=container", "", "Host", "evil.example", "User-Agent", fmBrowser, "Sec-Fetch-Site", "same-origin", "Content-Length", "0")
		if r.Code != 403 {
			t.Errorf("S3 OPEN: azblob port, Host evil.example = HTTP %d", r.Code)
		}
	}
	// rebinding when the attacker's page is read: a refused response carries no CORS header
	r = fmDo(t, "GET", srv.URL+"/_pogi/api/requests", "", "Host", "evil.example", "Origin", "http://evil.example", "User-Agent", fmBrowser)
	if r.Code != 403 || r.H.Get("Access-Control-Allow-Origin") != "" {
		t.Errorf("S3 OPEN: rebound read = HTTP %d, ACAO %q", r.Code, r.H.Get("Access-Control-Allow-Origin"))
	}
}

// ---- real-binary helpers (S4, S5) ----

type fmBuf struct {
	mu sync.Mutex
	b  bytes.Buffer
}

func (f *fmBuf) Write(p []byte) (int, error) { f.mu.Lock(); defer f.mu.Unlock(); return f.b.Write(p) }
func (f *fmBuf) String() string              { f.mu.Lock(); defer f.mu.Unlock(); return f.b.String() }

func fmFreePort(t testing.TB) int {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	return ln.Addr().(*net.TCPAddr).Port
}

func fmBuild(t testing.TB) string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "pogi")
	out, err := exec.Command("go", append(goBuildArgs(), "-o", bin, "../cmd/pogi")...).CombinedOutput()
	if err != nil {
		t.Fatalf("go build: %v\n%s", err, out)
	}
	return bin
}

// fmEnv is the environment for a child pogi: no POGI_* of the caller, and a Docker engine that is not there.
func fmEnv(extra ...string) []string {
	var env []string
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "POGI_") && !strings.HasPrefix(kv, "DOCKER_HOST=") && !strings.HasPrefix(kv, "AWS_") {
			env = append(env, kv)
		}
	}
	return append(append(env, extra...), "DOCKER_HOST=unix:///nonexistent/pogi-audit.sock", "NO_COLOR=1")
}

type fmProc struct {
	cmd  *exec.Cmd
	out  *fmBuf
	pid  int
	done chan error
}

func fmStart(t testing.TB, bin string, env []string, args ...string) *fmProc {
	t.Helper()
	p := &fmProc{out: &fmBuf{}, done: make(chan error, 1)}
	p.cmd = exec.Command(bin, args...)
	p.cmd.Env = env
	p.cmd.Stdout, p.cmd.Stderr = p.out, p.out
	if err := p.cmd.Start(); err != nil {
		t.Fatal(err)
	}
	p.pid = p.cmd.Process.Pid
	go func() { p.done <- p.cmd.Wait() }()
	t.Cleanup(p.stop)
	return p
}

func (p *fmProc) stop() {
	select {
	case err := <-p.done:
		p.done <- err
		return
	default:
	}
	p.cmd.Process.Signal(syscall.SIGTERM)
	select {
	case err := <-p.done:
		p.done <- err
	case <-time.After(15 * time.Second):
		p.cmd.Process.Kill()
		<-p.done
	}
}

func (p *fmProc) waitFor(t testing.TB, s string) {
	t.Helper()
	for end := time.Now().Add(60 * time.Second); time.Now().Before(end); time.Sleep(100 * time.Millisecond) {
		if strings.Contains(p.out.String(), s) {
			return
		}
		select {
		case err := <-p.done:
			p.done <- err
			t.Fatalf("pogi exited early: %v\n%s", err, p.out.String())
		default:
		}
	}
	t.Fatalf("pogi never printed %q:\n%s", s, p.out.String())
}

// ---- S5: secrets in logs and responses ----

func TestSecretsAreHiddenInRequestLog(t *testing.T) {
	bin := fmBuild(t)
	port, dir := fmFreePort(t), t.TempDir()
	p := fmStart(t, bin, fmEnv(), "start", "--headless", "--data-dir", dir, "--services", "aws,azure,gcp", "--port", fmt.Sprint(port),
		"--smtp-port", "-1", "--amqp-port", "-1", "--mqtt-port", "-1", "--transfer-port", "-1")
	p.waitFor(t, "Ready.")
	base := fmt.Sprintf("http://127.0.0.1:%d", port)
	secrets := map[string]string{} // where it was sent -> the value
	add := func(label, v string) { secrets[label] = v }

	// request bodies
	add("SSM SecureString Value", "CANARY-SSM-7f3a")
	fmSigned(t, base, "ssm", "POST", "/", fmJ11, "AmazonSSM.PutParameter", `{"Name":"/s5/p","Value":"CANARY-SSM-7f3a","Type":"SecureString"}`)
	add("Secrets Manager SecretString", "CANARY-SM-91bc")
	fmSigned(t, base, "secretsmanager", "POST", "/", fmJ11, "secretsmanager.CreateSecret", `{"Name":"s5","SecretString":"CANARY-SM-91bc"}`)
	add("IAM CreateLoginProfile Password", "CANARY-IAMPW-55d0")
	fmSigned(t, base, "iam", "POST", "/", fmForm, "", "Action=CreateUser&UserName=u5&Version=2010-05-08")
	fmSigned(t, base, "iam", "POST", "/", fmForm, "", "Action=CreateLoginProfile&UserName=u5&Password=CANARY-IAMPW-55d0&Version=2010-05-08")
	// response bodies
	r := fmSigned(t, base, "iam", "POST", "/", fmForm, "", "Action=CreateAccessKey&UserName=u5&Version=2010-05-08")
	if m := regexp.MustCompile(`<SecretAccessKey>([^<]+)`).FindStringSubmatch(r.Body); m != nil {
		add("IAM CreateAccessKey response SecretAccessKey", m[1])
	}
	r = fmSigned(t, base, "sts", "POST", "/", fmForm, "", "Action=AssumeRole&RoleArn=arn:aws:iam::000000000000:role/r&RoleSessionName=s&Version=2011-06-15")
	if m := regexp.MustCompile(`<SessionToken>([^<]+)`).FindStringSubmatch(r.Body); m != nil {
		add("STS AssumeRole response SessionToken", m[1])
	}
	// Cognito: sign up and sign in; the tokens come back in the response
	cog := func(op, body string) fmRes {
		return fmSigned(t, base, "cognito-idp", "POST", "/", fmJ11, "AWSCognitoIdentityProviderService."+op, body)
	}
	pool := cog("CreateUserPool", `{"PoolName":"p5"}`)
	var poolID string
	if m := regexp.MustCompile(`"Id":"([^"]+)"`).FindStringSubmatch(pool.Body); m != nil {
		poolID = m[1]
	}
	cl := cog("CreateUserPoolClient", `{"UserPoolId":"`+poolID+`","ClientName":"c5","ExplicitAuthFlows":["ALLOW_USER_PASSWORD_AUTH","ALLOW_REFRESH_TOKEN_AUTH"]}`)
	var clientID string
	if m := regexp.MustCompile(`"ClientId":"([^"]+)"`).FindStringSubmatch(cl.Body); m != nil {
		clientID = m[1]
	}
	add("Cognito SignUp Password", "CANARY-Cog-Pw-1!aA")
	cog("SignUp", `{"ClientId":"`+clientID+`","Username":"u5","Password":"CANARY-Cog-Pw-1!aA"}`)
	cog("AdminConfirmSignUp", `{"UserPoolId":"`+poolID+`","Username":"u5"}`)
	auth := cog("InitiateAuth", `{"ClientId":"`+clientID+`","AuthFlow":"USER_PASSWORD_AUTH","AuthParameters":{"USERNAME":"u5","PASSWORD":"CANARY-Cog-Pw-1!aA"}}`)
	for _, f := range []string{"AccessToken", "IdToken", "RefreshToken"} {
		if m := regexp.MustCompile(`"` + f + `":"([^"]+)"`).FindStringSubmatch(auth.Body); m != nil {
			add("Cognito InitiateAuth response "+f, m[1])
		}
	}
	// RDS master password (no Docker engine: the call fails, but it is logged)
	add("RDS MasterUserPassword", "CANARY-RDS-2e9c")
	fmSigned(t, base, "rds", "POST", "/", fmForm, "", "Action=CreateDBInstance&DBInstanceIdentifier=db5&DBInstanceClass=db.t3.micro&Engine=postgres&MasterUsername=admin&MasterUserPassword=CANARY-RDS-2e9c&AllocatedStorage=20&Version=2014-10-31")
	// Lambda environment variables
	add("Lambda environment variable", "CANARY-ENV-c41d")
	fmSigned(t, base, "lambda", "POST", "/2015-03-31/functions", "application/json", "",
		`{"FunctionName":"f5","Runtime":"python3.12","Role":"arn:aws:iam::000000000000:role/r","Handler":"index.handler","Environment":{"Variables":{"DB_PASSWORD":"CANARY-ENV-c41d"}},"Code":{"ZipFile":"`+base64.StdEncoding.EncodeToString(pyZip("def handler(e,c): pass"))+`"}}`)
	// headers
	add("X-Amz-Security-Token header", "CANARY-TOKEN-hdr-88")
	fmSigned(t, base, "sqs", "POST", "/", fmForm, "", "Action=ListQueues&Version=2012-11-05", "X-Amz-Security-Token", "CANARY-TOKEN-hdr-88")
	// query strings
	add("pre-signed URL X-Amz-Security-Token", "CANARY-TOKEN-qs-77")
	fmDo(t, "GET", base+"/nobucket/k?X-Amz-Security-Token=CANARY-TOKEN-qs-77&X-Amz-Signature=sig", "")
	add("Google API key in ?key=", "CANARY-GKEY-12")
	fmDo(t, "GET", base+"/storage/v1/b?project=p&key=CANARY-GKEY-12", "")
	// Azure and Google bodies
	add("Key Vault secret value", "CANARY-KV-6a6a")
	fmDo(t, "PUT", base+"/secrets/kv5?api-version=7.4", `{"value":"CANARY-KV-6a6a"}`, "Authorization", "Bearer CANARY-BEARER-9f", "Content-Type", "application/json")
	add("Azure Bearer token header", "CANARY-BEARER-9f")
	add("Google Secret Manager payload (base64)", base64.StdEncoding.EncodeToString([]byte("CANARY-GSM-3b3b")))
	fmDo(t, "POST", base+"/v1/projects/my-project/secrets?secretId=g5", `{"replication":{"automatic":{}}}`, "Content-Type", "application/json")
	fmDo(t, "POST", base+"/v1/projects/my-project/secrets/g5:addVersion", `{"payload":{"data":"`+base64.StdEncoding.EncodeToString([]byte("CANARY-GSM-3b3b"))+`"}}`, "Content-Type", "application/json")
	add("Azure SQL administratorLoginPassword", "CANARY-AZSQL-0d0d")
	fmDo(t, "PUT", base+"/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg5/providers/Microsoft.Sql/servers/sql5?api-version=2021-11-01",
		`{"location":"eastus","properties":{"administratorLogin":"a","administratorLoginPassword":"CANARY-AZSQL-0d0d"}}`, "Authorization", "Bearer x", "Content-Type", "application/json")
	time.Sleep(500 * time.Millisecond)

	// places a user or a log reader can see
	places := map[string]string{}
	places["pogi start output (stderr and stdout; pogi.log in TUI mode is the same logger)"] = p.out.String()
	lg, _ := exec.Command(bin, "logs", "--endpoint", base, "-n", "500").CombinedOutput()
	places["pogi logs"] = string(lg)
	list := fmDo(t, "GET", base+"/_pogi/api/requests?limit=1000", "")
	places["Activity API list"] = list.Body
	var ids []string
	for _, m := range regexp.MustCompile(`"id":(\d+)`).FindAllStringSubmatch(list.Body, -1) {
		ids = append(ids, m[1])
	}
	var detail, pages strings.Builder
	for _, id := range ids {
		detail.WriteString(fmDo(t, "GET", base+"/_pogi/api/requests/"+id, "").Body)
		pages.WriteString(fmDo(t, "GET", base+"/_pogi/requests/"+id, "").Body)
	}
	places["Activity API detail"] = detail.String()
	places["console request pages"] = pages.String()
	for _, pth := range []string{"/_pogi/", "/_pogi/requests", "/_pogi/tasks", "/_pogi/flows", "/_pogi/search?q=CANARY"} {
		places["console "+pth] = fmDo(t, "GET", base+pth, "").Body
	}
	// the data dir: any file with a canary
	filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err == nil && !info.IsDir() && info.Size() < 50<<20 {
			b, _ := os.ReadFile(path)
			places["file "+strings.TrimPrefix(path, dir)] = string(b)
		}
		return nil
	})

	t.Logf("S5 sent %d secrets, read back %d request-log entries", len(secrets), len(ids))
	for label, v := range secrets {
		var leaks []string
		for pl, text := range places {
			if strings.Contains(pl, "file ") && !strings.Contains(pl, "log") {
				continue // state files hold the resources themselves: not a log
			}
			if strings.Contains(text, v) || strings.Contains(text, strings.ReplaceAll(v, "!", `\u0021`)) {
				leaks = append(leaks, pl)
			}
		}
		if len(leaks) > 0 {
			t.Errorf("S5 OPEN: %s leaks into: %s", label, strings.Join(leaks, "; "))
		} else {
			t.Logf("S5 ok: %s is not in any log", label)
		}
	}
}
