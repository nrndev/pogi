package iam

import (
	"cmp"
	"encoding/json"
	"net/netip"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/nrndev/pogi/internal/core"
)

// IAM enforcement (pogi start --iam soft|strict): every AWS request signed by
// an IAM user or an assumed role is checked against the caller's identity-based
// policies, its permissions boundary and, in a member account of an
// organization, its service control policies. Root and the default test
// credentials are never checked.
//
// S3 bucket policies are evaluated too (withBucketPolicy), and so are the Deny
// statements of API Gateway resource policies (ResourcePolicyDenies).
// ponytail: other resource-based policies, session policies and role trust
// policies (on AssumeRole) are not evaluated, and SCPs do not restrict a member
// account's root user as they do on AWS. Resources come from common request
// parameters, and a request whose resource pogi cannot tell matches any Allow
// statement.

// scpSource is the organizations service: the SCP documents that govern an
// account, one list per level from the root down (nil when none apply).
type scpSource interface {
	SCPs(account string) [][]string
}

// authorize is the hub's Authorize hook. It runs in every mode: off records the
// request and allows it.
func (s *Service) authorize(c *core.Ctx) *core.Error {
	if c.Principal == "" || strings.HasSuffix(c.Principal, ":root") {
		return nil
	}
	action := actionOf(c.Service, c.Op)
	if action == "sts:GetCallerIdentity" || action == "sts:GetSessionToken" {
		return nil // AWS requires no permission for these, and policies cannot deny them
	}
	resource, keys := resourceOf(c), contextKeys(c)
	checks := []access{{action, resource, keys}}
	if c.Service == "s3" {
		if c.Op == "DeleteObjects" {
			s.authorizeDeleteObjects(c, keys)
			return nil
		}
		checks = s3Accesses(c, checks[0])
	}
	decision, reason := "allowed", ""
	for _, a := range checks {
		d, r := s.evaluate(c, a)
		s.record(principalOf(c), a.action, a.resource, d, r)
		if d != "allowed" && decision == "allowed" {
			decision, reason, action, resource = d, r, a.action, a.resource
		}
	}
	if mode := c.Hub.IAMMode(); mode != "soft" && mode != "strict" {
		return nil // recorded only: the console turns it into a policy
	}
	if decision == "allowed" {
		c.IAM = "allow " + action
		return nil
	}
	c.IAM = "deny " + action + ": " + reason
	code, status := "AccessDeniedException", 403 // rest-json services answer 403
	if svc := c.Hub.Service(c.Service); svc != nil {
		switch svc.Info().Protocol {
		case "query", "rest-xml":
			code = "AccessDenied"
		case "json":
			status = 400 // the JSON protocols (SQS, Secrets Manager, DynamoDB) answer 400
		}
	}
	if !strings.HasPrefix(reason, "with ") {
		reason = "because " + reason
	}
	return core.Errorf(status, code, "User: %s is not authorized to perform: %s on resource: %s %s",
		c.Principal, action, cmp.Or(resource, "*"), reason)
}

// evaluate decides one check: the caller's identity policies (within its
// permissions boundary), then an S3 bucket policy, then the service control
// policies of its account.
func (s *Service) evaluate(c *core.Ctx, a access) (string, string) {
	decision, reason := s.decideFor(c.Principal, a.action, a.resource, a.keys) // identity policies within the boundary
	decision, reason = withBucketPolicy(c, a, decision, reason)
	if org, ok := c.Hub.Service("organizations").(scpSource); ok && decision != "explicitDeny" {
		if d, r := decideSCP(org.SCPs(c.Account), a.action, a.resource, a.keys); d != "allowed" {
			decision, reason = d, r
		}
	}
	return decision, reason
}

// decideFor is decide over a user's or role's identity policies, then its
// permissions boundary: the boundary must allow the action too.
func (s *Service) decideFor(principal, action, resource string, keys map[string]string) (string, string) {
	decision, reason := decide(s.PoliciesFor(principal), action, resource, keys)
	if decision != "allowed" {
		return decision, reason
	}
	if doc, ok := s.boundaryFor(principal); ok {
		switch d, _ := decide([]string{doc}, action, resource, keys); d {
		case "explicitDeny":
			return d, "with an explicit deny in a permissions boundary"
		case "implicitDeny":
			return d, "no permissions boundary allows the " + action + " action"
		}
	}
	return decision, reason
}

// boundaryFor is the document of the permissions boundary of a user or role
// ARN (assumed-role ARNs map to the role); ok is false when there is none.
func (s *Service) boundaryFor(principalArn string) (string, bool) {
	_, _, account, res, ok := core.ParseARN(principalArn)
	if !ok {
		return "", false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	a := s.st.Accounts[account]
	if a == nil {
		return "", false
	}
	var b *Boundary
	kind, rest, _ := strings.Cut(res, "/")
	switch kind {
	case "user":
		if u := a.Users[lower(rest[strings.LastIndex(rest, "/")+1:])]; u != nil {
			b = u.PermissionsBoundary
		}
	case "role", "assumed-role":
		name := rest[strings.LastIndex(rest, "/")+1:]
		if kind == "assumed-role" {
			name, _, _ = strings.Cut(rest, "/")
		}
		if r := a.Roles[lower(name)]; r != nil {
			b = r.PermissionsBoundary
		}
	}
	if b == nil {
		return "", false
	}
	p, err := s.policy(b.PermissionsBoundaryArn)
	if err != nil {
		return "", false
	}
	return p.document(), true
}

// decideSCP applies service control policies: every level from the root down
// to the account must allow the action, and none may deny it.
func decideSCP(levels [][]string, action, resource string, keys map[string]string) (string, string) {
	decision, reason := "allowed", ""
	for _, docs := range levels {
		switch d, _ := decide(docs, action, resource, keys); d {
		case "explicitDeny":
			return d, "with an explicit deny in a service control policy"
		case "implicitDeny":
			decision, reason = d, "no service control policy allows the "+action+" action"
		}
	}
	return decision, reason
}

// decide applies IAM's evaluation logic: an explicit Deny wins, then any Allow.
// It returns allowed, explicitDeny or implicitDeny (the SimulatePolicy words).
func decide(docs []string, action, resource string, keys map[string]string) (string, string) {
	allowed := false
	for _, d := range docs {
		for _, st := range statements(d) {
			deny := st["Effect"] == "Deny"
			if !applies(st, action, resource, keys, deny) {
				continue
			}
			if deny {
				return "explicitDeny", "with an explicit deny in an identity-based policy"
			}
			allowed = allowed || st["Effect"] == "Allow"
		}
	}
	if !allowed {
		return "implicitDeny", "no identity-based policy allows the " + action + " action"
	}
	return "allowed", ""
}

// ResourcePolicyDenies reports whether a resource-based policy (an API
// Gateway RestApi policy, say) holds a Deny statement that covers the caller,
// action and resource. Allow statements are not needed to deny, so an
// Allow-only policy never blocks here.
func ResourcePolicyDenies(doc, principal, action, resource string, keys map[string]string) bool {
	for _, st := range statements(doc) {
		if st["Effect"] == "Deny" && principalMatches(st["Principal"], principal) && applies(st, action, resource, keys, true) {
			return true
		}
	}
	return false
}

// principalMatches reports whether a statement's Principal ("*", {"AWS": ...})
// covers the caller. A statement with no Principal covers nobody.
func principalMatches(p any, caller string) bool {
	if m, ok := p.(map[string]any); ok {
		p = m["AWS"]
	}
	for _, x := range asStrings(p) {
		if x == "*" || x == caller {
			return true
		}
	}
	return false
}

func statements(doc string) []map[string]any {
	var d struct{ Statement any }
	if json.Unmarshal([]byte(doc), &d) != nil {
		u, err := url.QueryUnescape(doc)
		if err != nil || json.Unmarshal([]byte(u), &d) != nil {
			return nil
		}
	}
	var out []map[string]any
	for _, st := range asList(d.Statement) {
		if m, ok := st.(map[string]any); ok {
			out = append(out, m)
		}
	}
	return out
}

func asList(v any) []any {
	if l, ok := v.([]any); ok {
		return l
	}
	if v == nil {
		return nil
	}
	return []any{v}
}

func asStrings(v any) []string {
	var out []string
	for _, x := range asList(v) {
		switch t := x.(type) {
		case string:
			out = append(out, t)
		case bool:
			out = append(out, strconv.FormatBool(t))
		case float64:
			out = append(out, strconv.FormatFloat(t, 'f', -1, 64))
		}
	}
	return out
}

// applies reports whether a statement covers the request. An unknown
// resource ("") matches Allow statements but only "*" Deny statements.
func applies(st map[string]any, action, resource string, keys map[string]string, deny bool) bool {
	if a, ok := st["Action"]; ok && !matchAny(asStrings(a), action, true, keys) {
		return false
	}
	if a, ok := st["NotAction"]; ok && matchAny(asStrings(a), action, true, keys) {
		return false
	}
	if r, ok := st["Resource"]; ok {
		pats := asStrings(r)
		if resource == "" && deny && !matchAny(pats, "*", false, keys) || resource != "" && !matchAny(pats, resource, false, keys) {
			return false
		}
	}
	if r, ok := st["NotResource"]; ok && (resource == "" && deny || resource != "" && matchAny(asStrings(r), resource, false, keys)) {
		return false
	}
	cond, _ := st["Condition"].(map[string]any)
	for op, block := range cond {
		m, _ := block.(map[string]any)
		for key, want := range m {
			if !condition(op, keys, strings.ToLower(key), asStrings(want)) {
				return false
			}
		}
	}
	return true
}

func matchAny(patterns []string, s string, fold bool, keys map[string]string) bool {
	if fold {
		s = strings.ToLower(s)
	}
	for _, p := range patterns {
		p = substitute(p, keys)
		if fold {
			p = strings.ToLower(p)
		}
		if glob(p, s) {
			return true
		}
	}
	return false
}

// glob matches IAM wildcards: * is any run of characters, ? exactly one.
func glob(p, s string) bool {
	px, sx, star, mark := 0, 0, -1, 0
	for sx < len(s) {
		switch {
		case px < len(p) && (p[px] == '?' || p[px] == s[sx]):
			px, sx = px+1, sx+1
		case px < len(p) && p[px] == '*':
			star, mark = px, sx
			px++
		case star >= 0:
			mark++
			px, sx = star+1, mark
		default:
			return false
		}
	}
	for px < len(p) && p[px] == '*' {
		px++
	}
	return px == len(p)
}

var policyVar = regexp.MustCompile(`\$\{([^}]+)\}`)

// substitute fills policy variables such as ${aws:username}.
func substitute(p string, keys map[string]string) string {
	if !strings.Contains(p, "${") {
		return p
	}
	return policyVar.ReplaceAllStringFunc(p, func(m string) string {
		if v, ok := keys[strings.ToLower(m[2:len(m)-1])]; ok {
			return v
		}
		return m
	})
}

// condition evaluates one condition operator for one key.
func condition(op string, keys map[string]string, key string, want []string) bool {
	op = strings.TrimPrefix(strings.TrimPrefix(op, "ForAnyValue:"), "ForAllValues:")
	have, ok := keys[key]
	if op == "Null" {
		return len(want) > 0 && (want[0] == "true") == !ok
	}
	ifExists := strings.HasSuffix(op, "IfExists")
	op = strings.TrimSuffix(op, "IfExists")
	base := strings.Replace(op, "Not", "", 1)
	negated := base != op
	if !ok {
		return ifExists || negated
	}
	for _, w := range want {
		w = substitute(w, keys)
		var m bool
		switch base {
		case "StringEquals", "BinaryEquals":
			m = have == w
		case "StringEqualsIgnoreCase", "Bool":
			m = strings.EqualFold(have, w)
		case "StringLike", "ArnEquals", "ArnLike":
			m = glob(w, have)
		case "NumericEquals", "NumericLessThan", "NumericLessThanEquals", "NumericGreaterThan", "NumericGreaterThanEquals":
			a, err1 := strconv.ParseFloat(have, 64)
			b, err2 := strconv.ParseFloat(w, 64)
			m = err1 == nil && err2 == nil && compare(base[len("Numeric"):], a, b)
		case "DateEquals", "DateLessThan", "DateLessThanEquals", "DateGreaterThan", "DateGreaterThanEquals":
			a, err1 := parseDate(have)
			b, err2 := parseDate(w)
			m = err1 == nil && err2 == nil && compare(base[len("Date"):], float64(a.Unix()), float64(b.Unix()))
		case "IpAddress":
			addr, err := netip.ParseAddr(have)
			pfx, err2 := netip.ParsePrefix(w)
			if err2 != nil {
				if a, err3 := netip.ParseAddr(w); err3 == nil {
					pfx, err2 = a.Prefix(a.BitLen())
				}
			}
			m = err == nil && err2 == nil && pfx.Contains(addr)
		default:
			return false // operators pogi does not know never match
		}
		if m {
			return !negated
		}
	}
	return negated
}

func compare(rel string, a, b float64) bool {
	switch rel {
	case "Equals":
		return a == b
	case "LessThan":
		return a < b
	case "LessThanEquals":
		return a <= b
	case "GreaterThan":
		return a > b
	}
	return a >= b
}

func parseDate(s string) (time.Time, error) {
	if n, err := strconv.ParseInt(s, 10, 64); err == nil {
		return time.Unix(n, 0), nil
	}
	return time.Parse(time.RFC3339, s)
}

// contextKeys are the global condition keys pogi can provide (lower case).
func contextKeys(c *core.Ctx) map[string]string {
	now := time.Now().UTC()
	k := map[string]string{
		"aws:principalarn": c.Principal, "aws:principalaccount": c.Account, "aws:requestedregion": c.Region,
		"aws:securetransport": "false", "aws:sourceip": "127.0.0.1", "aws:viaawsservice": "false",
		"aws:principalisawsservice": "false", // callers here are IAM principals, never AWS services
		"aws:currenttime":           now.Format(time.RFC3339), "aws:epochtime": strconv.FormatInt(now.Unix(), 10),
	}
	if id, ok := c.Hub.Identity(c.AccessKey); ok {
		k["aws:userid"] = id.UserID
	}
	_, _, account, res, _ := core.ParseARN(c.Principal)
	switch kind, rest, _ := strings.Cut(res, "/"); kind {
	case "user":
		k["aws:principaltype"], k["aws:username"] = "User", rest[strings.LastIndex(rest, "/")+1:]
	case "assumed-role":
		role, _, _ := strings.Cut(rest, "/")
		k["aws:principaltype"], k["aws:principalarn"] = "AssumedRole", core.GlobalARN("iam", c.Region, account, "role/"+role)
	}
	return k
}

// actions whose IAM name differs from the API operation.
var actionAlias = map[string]string{
	"s3:listobjects": "s3:ListBucket", "s3:listobjectsv2": "s3:ListBucket", "s3:headbucket": "s3:ListBucket",
	"s3:listobjectversions": "s3:ListBucketVersions", "s3:headobject": "s3:GetObject", "s3:getobjectattributes": "s3:GetObject",
	"s3:listbuckets": "s3:ListAllMyBuckets", "s3:createmultipartupload": "s3:PutObject", "s3:uploadpart": "s3:PutObject",
	"s3:uploadpartcopy": "s3:PutObject", "s3:completemultipartupload": "s3:PutObject", "s3:copyobject": "s3:PutObject",
	"s3:postobject": "s3:PutObject", "s3:deleteobjects": "s3:DeleteObject", "s3:listparts": "s3:ListMultipartUploadParts",
	"s3:listmultipartuploads": "s3:ListBucketMultipartUploads", "s3:getbucketencryption": "s3:GetEncryptionConfiguration",
	"s3:putbucketencryption": "s3:PutEncryptionConfiguration", "s3:getbucketlifecycleconfiguration": "s3:GetLifecycleConfiguration",
	"s3:putbucketlifecycleconfiguration": "s3:PutLifecycleConfiguration", "s3:getbucketnotificationconfiguration": "s3:GetBucketNotification",
	"s3:putbucketnotificationconfiguration": "s3:PutBucketNotification", "s3:getpublicaccessblock": "s3:GetBucketPublicAccessBlock",
	"s3:putpublicaccessblock": "s3:PutBucketPublicAccessBlock", "s3:deletebuckettagging": "s3:PutBucketTagging",
	"s3:deletebucketencryption": "s3:PutEncryptionConfiguration", "s3:deletebucketlifecycle": "s3:PutLifecycleConfiguration",
	"s3:deletebucketcors": "s3:PutBucketCORS", "s3:deletepublicaccessblock": "s3:PutBucketPublicAccessBlock",
	"sqs:sendmessagebatch": "sqs:SendMessage", "sqs:deletemessagebatch": "sqs:DeleteMessage",
	"sqs:changemessagevisibilitybatch": "sqs:ChangeMessageVisibility", "sns:publishbatch": "sns:Publish",
	"lambda:invoke": "lambda:InvokeFunction", "lambda:invokewithresponsestream": "lambda:InvokeFunction",
}

// prefixes maps pogi service names to IAM service prefixes where they differ.
var prefixes = map[string]string{"stepfunctions": "states", "resourcegroupstaggingapi": "tag", "elbv2": "elasticloadbalancing", "opensearch": "es"}

func actionOf(service, op string) string {
	a := cmp.Or(prefixes[service], service) + ":" + op
	if alias, ok := actionAlias[strings.ToLower(a)]; ok {
		return alias
	}
	return a
}

// resourceOf derives the request's resource ARN from its parameters ("" when unknown).
func resourceOf(c *core.Ctx) string {
	p := params(c.Payload())
	arn := func(service, resource string) string { return core.ARN(service, c.Region, c.Account, resource) }
	first := func(names ...string) string {
		for _, n := range names {
			if v := p[n]; v != "" {
				return v
			}
		}
		return ""
	}
	isARN := func(s string) bool { return strings.HasPrefix(s, "arn:") }
	switch c.Service {
	case "s3":
		bucket, key := s3Target(c.Host, c.Hub.Cfg.Hostname, c.Path)
		switch {
		case bucket == "":
			return ""
		case key == "":
			return core.GlobalARN("s3", c.Region, "", bucket)
		}
		return core.GlobalARN("s3", c.Region, "", bucket+"/"+key)
	case "sqs":
		if u := p["QueueUrl"]; u != "" {
			return arn("sqs", u[strings.LastIndex(u, "/")+1:])
		}
		if n := p["QueueName"]; n != "" {
			return arn("sqs", n)
		}
	case "sns":
		if v := first("TopicArn", "TargetArn", "ResourceArn"); v != "" {
			return v
		}
		if n := p["Name"]; n != "" {
			return arn("sns", n)
		}
	case "dynamodb":
		if v := first("StreamArn", "ResourceArn", "TableArn"); v != "" {
			return v
		}
		if n := p["TableName"]; n != "" {
			if isARN(n) {
				return n
			}
			return arn("dynamodb", "table/"+n)
		}
	case "lambda":
		if _, rest, ok := strings.Cut(c.Path, "/functions/"); ok {
			if name, _, _ := strings.Cut(rest, "/"); name != "" {
				if isARN(name) {
					return name
				}
				return arn("lambda", "function:"+name)
			}
		}
		if n := p["FunctionName"]; n != "" {
			return arn("lambda", "function:"+n)
		}
	case "kinesis":
		if v := p["StreamARN"]; v != "" {
			return v
		}
		if n := p["StreamName"]; n != "" {
			return arn("kinesis", "stream/"+n)
		}
	case "firehose":
		if n := p["DeliveryStreamName"]; n != "" {
			return arn("firehose", "deliverystream/"+n)
		}
	case "secretsmanager":
		id := first("SecretId", "Name")
		if id == "" || isARN(id) {
			return id
		}
		var out struct{ ARN string } // secret ARNs end in a random suffix: ask the service
		if c.Hub.Call(c.Account, c.Region, "secretsmanager", "DescribeSecret", map[string]string{"SecretId": id}, &out) == nil {
			return out.ARN
		}
		return arn("secretsmanager", "secret:"+id)
	case "ssm":
		if n := first("Name", "Names", "Path"); n != "" {
			if isARN(n) {
				return n
			}
			return arn("ssm", "parameter/"+strings.TrimPrefix(n, "/"))
		}
	case "kms":
		id := p["KeyId"]
		switch {
		case id == "" || isARN(id):
			return id
		case strings.HasPrefix(id, "alias/"):
			var out struct{ KeyMetadata struct{ Arn string } }
			if c.Hub.Call(c.Account, c.Region, "TrentService", "DescribeKey", map[string]string{"KeyId": id}, &out) == nil {
				return out.KeyMetadata.Arn
			}
			return arn("kms", id)
		}
		return arn("kms", "key/"+id)
	case "logs":
		if g := first("logGroupName", "logGroupIdentifier"); g != "" {
			if isARN(g) {
				return g
			}
			if s := p["logStreamName"]; s != "" {
				return arn("logs", "log-group:"+g+":log-stream:"+s)
			}
			return arn("logs", "log-group:"+g)
		}
	case "stepfunctions":
		if v := first("stateMachineArn", "stateMachineAliasArn", "stateMachineVersionArn", "executionArn", "activityArn", "resourceArn"); v != "" {
			return v
		}
		if n := p["name"]; n != "" && c.Op == "CreateStateMachine" {
			return arn("states", "stateMachine:"+n)
		}
	case "events":
		if v := p["ResourceARN"]; v != "" {
			return v
		}
		bus := lastSegment(p["EventBusName"])
		if r := first("Rule", "Name"); r != "" && c.Op != "CreateEventBus" && c.Op != "DeleteEventBus" && c.Op != "DescribeEventBus" {
			if bus != "" && bus != "default" {
				return arn("events", "rule/"+bus+"/"+r)
			}
			return arn("events", "rule/"+r)
		}
		return arn("events", "event-bus/"+cmp.Or(bus, p["Name"], "default"))
	case "iam":
		global := func(res string) string { return c.GlobalARN("iam", res) }
		switch {
		case p["PolicyArn"] != "":
			return p["PolicyArn"]
		case p["RoleName"] != "":
			return global("role/" + p["RoleName"])
		case p["UserName"] != "":
			return global("user/" + p["UserName"])
		case p["GroupName"] != "":
			return global("group/" + p["GroupName"])
		case p["InstanceProfileName"] != "":
			return global("instance-profile/" + p["InstanceProfileName"])
		}
	case "sts":
		return p["RoleArn"]
	case "cloudformation":
		if n := p["StackName"]; n != "" {
			if isARN(n) {
				return n
			}
			return arn("cloudformation", "stack/"+n+"/*")
		}
	}
	return ""
}

func lastSegment(s string) string { return s[strings.LastIndexAny(s, "/:")+1:] }

// params returns the top-level scalar request parameters (JSON or form encoded).
func params(body []byte) map[string]string {
	out := map[string]string{}
	var m map[string]any
	if json.Unmarshal(body, &m) == nil {
		for k, v := range m {
			if l := asStrings(v); len(l) > 0 {
				out[k] = l[0]
			}
		}
		return out
	}
	form, _ := url.ParseQuery(string(body))
	for k, v := range form {
		out[strings.TrimSuffix(strings.TrimSuffix(k, ".member.1"), ".1")] = v[0]
	}
	return out
}

// s3Target splits a path-style or virtual-hosted S3 request into bucket and key.
func s3Target(host, hostname, path string) (bucket, key string) {
	h := host
	if i := strings.LastIndexByte(h, ':'); i > 0 && !strings.Contains(h[i:], "]") {
		h = h[:i]
	}
	if i := strings.Index(h, ".s3"); i > 0 {
		return h[:i], strings.TrimPrefix(path, "/")
	}
	if b, base := core.SplitHost(h, hostname); b != "" && (base == hostname || base == "localhost") {
		return b, strings.TrimPrefix(path, "/")
	}
	bucket, key, _ = strings.Cut(strings.TrimPrefix(path, "/"), "/")
	return bucket, key
}
