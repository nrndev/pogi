package test

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
	"testing"

	"github.com/nrndev/pogi"
	"github.com/nrndev/pogi/internal/core"
	"go.yaml.in/yaml/v3"
)

var update = flag.Bool("update", false, "rewrite docs/reference/coverage.md, the Services table of README.md and internal/web/coverage.json")

type covRow struct {
	Title    string   `yaml:"title"`
	Cloud    string   `yaml:"cloud"`
	Depth    string   `yaml:"depth"`
	Services []string `yaml:"services"`
	Rest     bool     `yaml:"rest"`
	Docker   bool     `yaml:"docker"`
	Covered  string   `yaml:"covered"`
	NotYet   string   `yaml:"not_yet"`
	Guide    string   `yaml:"guide"` // a how-to for the row, relative to docs/reference/, with an optional #heading
}

// coverageEntry is one service in internal/web/coverage.json, which the web console embeds.
type coverageEntry struct {
	Title    string `json:"title"`
	Cloud    string `json:"cloud"`
	Category string `json:"category"`
	Depth    string `json:"depth"`
	Docker   bool   `json:"docker"`
	Covered  string `json:"covered"`
	NotYet   string `json:"not_yet"`
}

var clouds = []struct{ key, title, readme string }{
	{"aws", "AWS", "AWS"}, {"gcp", "Google Cloud", "Google Cloud"}, {"azure", "Azure", "Azure"},
}

// categoryNames are the console's service categories, in the order the console shows them.
var categoryNames = []string{
	"Storage", "Databases", "Messaging & events", "Compute & containers", "Networking",
	"Security & identity", "Observability", "Integration & workflow", "Analytics & AI",
	"Developer tools", "Management & governance",
}

// TestCoverageDocs joins docs/reference/coverage.yaml (depth, covered and not-yet text per row, and each
// service's console category) with the registry (every service's Info) and checks that
// docs/reference/coverage.md, the Services table in README.md and internal/web/coverage.json are what they
// generate. `go generate .` rewrites them.
func TestCoverageDocs(t *testing.T) {
	raw, err := os.ReadFile("../docs/reference/coverage.yaml")
	if err != nil {
		t.Fatal(err)
	}
	var doc struct {
		Intro      string              `yaml:"intro"`
		Categories map[string][]string `yaml:"categories"`
		Rows       []covRow            `yaml:"rows"`
		Parts      map[string]string   `yaml:"parts"`     // id: the product's id; not counted on its own
		Bundles    map[string][]string `yaml:"bundles"`   // id: the products it serves; each counts
		Uncounted  []string            `yaml:"uncounted"` // ids that are not a product
	}
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		t.Fatal(err)
	}
	// The category names in file order, which a map does not keep.
	var order struct {
		Categories yaml.Node `yaml:"categories"`
	}
	if err := yaml.Unmarshal(raw, &order); err != nil {
		t.Fatal(err)
	}
	var catNames []string
	for i := 0; i+1 < len(order.Categories.Content); i += 2 {
		catNames = append(catNames, order.Categories.Content[i].Value)
	}

	// The registry: name → cloud and title, in routing order.
	cloud := map[string]string{}
	title := map[string]string{}
	var names []string
	for _, svc := range pogi.New(pogi.Config{DataDir: t.TempDir()}, nil).Hub.Services() {
		i := svc.Info()
		cloud[i.Name] = strings.ToLower(i.Cloud)
		title[i.Name] = i.Title
		names = append(names, i.Name)
	}

	named := map[string]bool{}
	rest := -1
	for i, r := range doc.Rows {
		if !slices.Contains([]string{"Deep", "Core", "Thin"}, r.Depth) {
			t.Errorf("%s: depth %q", r.Title, r.Depth)
		}
		if r.Covered == "" {
			t.Errorf("%s: nothing covered", r.Title)
		}
		if r.Guide != "" {
			if err := guideExists(r.Guide); err != nil {
				t.Errorf("%s: guide: %v", r.Title, err)
			}
		}
		if r.Rest {
			if rest >= 0 || r.Cloud != "aws" {
				t.Errorf("%s: one aws row can take the rest", r.Title)
			}
			rest = i
		}
		for _, n := range r.Services {
			if c, ok := cloud[n]; !ok {
				t.Errorf("%s: %q is not a registered service", r.Title, n)
			} else if c != r.Cloud {
				t.Errorf("%s: %q is a %s service", r.Title, n, c)
			}
			named[n] = true
		}
	}
	var others []string // what the rest row takes
	for _, n := range names {
		switch {
		case named[n]:
		case cloud[n] == "aws" && rest >= 0:
			others = append(others, n)
		default:
			t.Errorf("service %q is in no row of docs/reference/coverage.yaml", n)
		}
	}

	// Each category is one of categoryNames and names registered services; each service is in one.
	inCat := map[string]string{}
	for _, c := range catNames {
		if !slices.Contains(categoryNames, c) {
			t.Errorf("category %q is not one of the %d console categories", c, len(categoryNames))
		}
		for _, n := range doc.Categories[c] {
			if _, ok := cloud[n]; !ok {
				t.Errorf("category %q: %q is not a registered service", c, n)
			} else if prev, dup := inCat[n]; dup {
				t.Errorf("service %q is in two categories: %q and %q", n, prev, c)
			}
			inCat[n] = c
		}
	}
	for _, n := range names {
		if inCat[n] == "" {
			t.Errorf("service %q is in no category of docs/reference/coverage.yaml", n)
		}
	}
	// The counting rule names registered ids: a part belongs to a product of its own cloud that is not a part.
	for n, of := range doc.Parts {
		switch {
		case cloud[n] == "" || cloud[of] == "":
			t.Errorf("parts: %q of %q: not registered", n, of)
		case cloud[n] != cloud[of]:
			t.Errorf("parts: %q is %s, %q is %s", n, cloud[n], of, cloud[of])
		case doc.Parts[of] != "":
			t.Errorf("parts: %q is part of %q, itself a part", n, of)
		}
	}
	for n, ps := range doc.Bundles {
		if cloud[n] == "" || len(ps) < 2 || doc.Parts[n] != "" {
			t.Errorf("bundles: %q needs to be a registered id that serves two or more products", n)
		}
	}
	for _, n := range doc.Uncounted {
		if cloud[n] == "" {
			t.Errorf("uncounted: %q is not registered", n)
		}
	}

	// internal/web/coverage.json: the categories in order, and each service's row data.
	entries := map[string]coverageEntry{}
	for _, r := range doc.Rows {
		for _, n := range r.Services {
			if _, ok := entries[n]; !ok {
				entries[n] = coverageEntry{Title: r.Title, Cloud: cloud[n], Category: inCat[n], Depth: r.Depth,
					Docker: r.Docker, Covered: r.Covered, NotYet: r.NotYet}
			}
		}
	}
	if rest >= 0 {
		r := doc.Rows[rest]
		for _, n := range others {
			entries[n] = coverageEntry{Title: title[n], Cloud: cloud[n], Category: inCat[n], Depth: r.Depth,
				Docker: r.Docker, Covered: strings.ReplaceAll(r.Covered, "{n}", fmt.Sprint(len(others))), NotYet: r.NotYet}
		}
	}
	// The depth split per cloud, from the same data as coverage.json: Deep and Core have real behavior.
	splits := map[string]*split{}
	for _, c := range clouds {
		splits[c.key] = &split{}
	}
	for _, n := range names {
		if doc.Parts[n] != "" || slices.Contains(doc.Uncounted, n) {
			continue
		}
		w := max(len(doc.Bundles[n]), 1)
		sp := splits[cloud[n]]
		sp.Total += w
		if entries[n].Depth == "Thin" {
			sp.Thin += w
		}
	}
	counts := countPhrases(splits)

	for _, path := range []string{"../README.md", "../CHANGELOG.md", "../docs/explanation/faq.md", "../docs/reference/compared.md"} {
		check(t, path, func(old string) string {
			if !countMark.MatchString(old) {
				t.Errorf("%s has no <!-- count:... --> mark", path)
			}
			return countMark.ReplaceAllStringFunc(old, func(m string) string {
				kind := countMark.FindStringSubmatch(m)[1]
				if counts[kind] == "" {
					t.Errorf("%s: unknown count %q", path, kind)
				}
				return "<!-- count:" + kind + " -->" + counts[kind] + "<!-- /count -->"
			})
		})
	}

	// The start banner samples show the product count, as the banner does (web.ServiceCount).
	total := 0
	for _, sp := range splits {
		total += sp.Total
	}
	for _, path := range []string{"../docs/tutorials/first-run.md", "../docs/reference/cli.md", "../docs/how-to/troubleshoot.md"} {
		check(t, path, func(old string) string {
			if !bannerCount.MatchString(old) {
				t.Errorf("%s has no start banner sample", path)
			}
			return bannerCount.ReplaceAllString(old, fmt.Sprintf("${1}%d services", total))
		})
	}

	var md, tbl strings.Builder
	md.WriteString("---\ntitle: Coverage\ndescription: What each emulated service does today, and what it does not yet.\n---\n\n")
	md.WriteString("<!-- Generated from docs/reference/coverage.yaml and the service registry by `go generate .`; edit the YAML. -->\n\n")
	md.WriteString(strings.TrimRight(doc.Intro, "\n") + "\n\n")
	fmt.Fprintf(&md, "pogi covers %s. Each service is followed by its service id, the name `pogi services` prints. A product counts once, however many service ids it has: see [How services are counted](#how-services-are-counted).\n", counts["total"])
	tbl.WriteString("| Cloud | Services |\n|---|---|\n")
	for _, c := range clouds {
		fmt.Fprintf(&md, "\n## %s\n\n| Service | Depth | Covered | Not yet |\n|---|---|---|---|\n", c.title)
		var plain, docker []string
		for _, r := range doc.Rows {
			if r.Cloud != c.key {
				continue
			}
			ids := r.Services
			covered := r.Covered
			if r.Rest {
				ids = []string{fmt.Sprintf("%d others", len(others))}
				covered = strings.ReplaceAll(covered, "{n}", fmt.Sprint(len(others)))
			}
			reg := "`" + strings.Join(ids, "`, `") + "`"
			if r.Rest {
				reg = ids[0]
			}
			name := r.Title
			if r.Guide != "" {
				name = "[" + r.Title + "](" + r.Guide + ")"
			}
			fmt.Fprintf(&md, "| %s · %s | %s | %s | %s |\n", name, reg, r.Depth, esc(covered), esc(r.NotYet))
			switch {
			case r.Rest:
			case r.Docker:
				docker = append(docker, r.Title)
			default:
				plain = append(plain, r.Title)
			}
		}
		line := strings.Join(plain, ", ")
		if c.key == "aws" {
			line += fmt.Sprintf(", and %d more long-tail services generated from the AWS API models (see [docs/reference/aws-long-tail.md](docs/reference/aws-long-tail.md))", len(others))
		}
		if len(docker) > 0 {
			line += "; with Docker running: " + strings.Join(docker, ", ")
		}
		fmt.Fprintf(&tbl, "| **%s** | %s |\n", c.readme, line)
	}

	md.WriteString("\n## How services are counted\n\nThe totals count products, as each cloud lists them on its products page, each with its own API. A product counts once, however many service ids pogi has for it.\n\n")
	for _, c := range clouds {
		var lines []string
		for _, n := range core.SortedKeys(doc.Parts) {
			if cloud[n] == c.key {
				lines = append(lines, fmt.Sprintf("`%s` is part of %s (`%s`)", n, title[doc.Parts[n]], doc.Parts[n]))
			}
		}
		for _, n := range core.SortedKeys(doc.Bundles) {
			if cloud[n] == c.key {
				lines = append(lines, fmt.Sprintf("`%s` serves %d products: %s", n, len(doc.Bundles[n]), strings.Join(doc.Bundles[n], ", ")))
			}
		}
		for _, n := range doc.Uncounted {
			if cloud[n] == c.key {
				lines = append(lines, fmt.Sprintf("`%s` is not a product", n))
			}
		}
		if len(lines) > 0 {
			fmt.Fprintf(&md, "- **%s:** %s.\n", c.title, strings.Join(lines, "; "))
		}
	}
	check(t, "../docs/reference/coverage.md", func(string) string { return md.String() })
	check(t, "../README.md", func(old string) string {
		const start, end = "<!-- services:start", "<!-- services:end -->"
		a, b := strings.Index(old, start), strings.Index(old, end)
		if a < 0 || b < a {
			t.Fatalf("README.md has no %q … %q block", start, end)
		}
		a += strings.Index(old[a:], "\n") + 1
		return old[:a] + tbl.String() + old[b:]
	})

	js, err := json.MarshalIndent(struct {
		Categories []string                 `json:"categories"`
		Counts     map[string]*split        `json:"counts"` // products per cloud, for the console and the website
		Services   map[string]coverageEntry `json:"services"`
	}{catNames, splits, entries}, "", " ")
	if err != nil {
		t.Fatal(err)
	}
	check(t, "../internal/web/coverage.json", func(string) string { return string(js) + "\n" })
}

func esc(s string) string { return strings.ReplaceAll(s, "|", `\|`) }

var (
	codeBlock = regexp.MustCompile("(?s)```.*?```")
	heading   = regexp.MustCompile(`(?m)^#{1,6}\s+(.*)$`)
	notSlug   = regexp.MustCompile(`[^\p{L}\p{N}_\- ]`)
)

// guideExists checks that a row's guide link, relative to docs/reference/, names a page that exists and, after
// a #, one of its headings, made into an anchor the way GitHub and the website do it.
func guideExists(link string) error {
	path, anchor, _ := strings.Cut(link, "#")
	raw, err := os.ReadFile("../docs/reference/" + path)
	if err != nil {
		return err
	}
	if anchor == "" {
		return nil
	}
	for _, m := range heading.FindAllStringSubmatch(codeBlock.ReplaceAllString(string(raw), ""), -1) {
		if strings.ReplaceAll(notSlug.ReplaceAllString(strings.ToLower(strings.TrimSpace(m[1])), ""), " ", "-") == anchor {
			return nil
		}
	}
	return fmt.Errorf("%s has no heading for #%s", path, anchor)
}

func TestCoverageGuideLinks(t *testing.T) {
	for link, ok := range map[string]bool{
		"../how-to/connect-your-tools.md":               true,
		"../how-to/connect-your-tools.md#sdks-and-clis": true,
		"../how-to/connect-your-tools.md#no-such":       false,
		"../how-to/no-such-page.md":                     false,
	} {
		if err := guideExists(link); (err == nil) != ok {
			t.Errorf("%s: %v", link, err)
		}
	}
}

// check compares a generated file with the one on disk, or rewrites it with -update.
func check(t *testing.T, path string, gen func(old string) string) {
	t.Helper()
	old, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	want := gen(string(old))
	if want == string(old) {
		return
	}
	if !*update {
		t.Errorf("%s is stale: run `go generate .` in the repo root", path)
		return
	}
	if err := os.WriteFile(path, []byte(want), 0o644); err != nil {
		t.Fatal(err)
	}
}

// A split is one cloud's products: all of them, and those that are Thin (the rest have real behavior).
type split struct {
	Total int `json:"total"`
	Thin  int `json:"thin"`
}

// countMark is a count in the docs that the coverage data fills in: <!-- count:total -->…<!-- /count -->.
var countMark = regexp.MustCompile(`<!-- count:(\w+) -->.*?<!-- /count -->`)

// bannerCount is the count in a `pogi start` banner sample: "pogi 0.1.0  ·  355 services".
var bannerCount = regexp.MustCompile(`(pogi \S+  ·  )\d+ services`)

// countPhrases are the counts the docs show, always with the depth split (the owner's rule), by kind:
// "total" for all three clouds, "aws" for AWS alone. The README's table takes bare numbers, one per cell:
// "<cloud>_services", "<cloud>_real" and "<cloud>_thin", where cloud is aws, gcp, azure or all.
func countPhrases(sp map[string]*split) map[string]string {
	a, g, z := sp["aws"], sp["gcp"], sp["azure"]
	one := func(s *split) string { return fmt.Sprintf("%d with real behavior, %d Thin", s.Total-s.Thin, s.Thin) }
	total := fmt.Sprintf("%d services: %d AWS (%s), %d Google Cloud (%s) and %d Azure (%s)",
		a.Total+g.Total+z.Total, a.Total, one(a), g.Total, one(g), z.Total, one(z))
	if a.Total == g.Total && g.Total == z.Total {
		total = fmt.Sprintf("%d services per cloud, %d in all: AWS has %s, Google Cloud %s, and Azure %s",
			a.Total, 3*a.Total, one(a), one(g), one(z))
	}
	m := map[string]string{"total": total, "aws": fmt.Sprintf("%d (%s)", a.Total, one(a))}
	all := &split{Total: a.Total + g.Total + z.Total, Thin: a.Thin + g.Thin + z.Thin}
	for k, s := range map[string]*split{"aws": a, "gcp": g, "azure": z, "all": all} {
		m[k+"_services"], m[k+"_real"], m[k+"_thin"] = fmt.Sprint(s.Total), fmt.Sprint(s.Total-s.Thin), fmt.Sprint(s.Thin)
	}
	return m
}
