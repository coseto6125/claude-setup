# Cluster spec

Analyze keywords with SERP overlap data and design hub-and-spoke content cluster architectures.

<!-- Original concept: Lutfiya Miller, Semantic Cluster Engine (Pro Hub Challenge) -->

## Steps

1. **Expand** the seed into 30-50 keyword variants using WebSearch (related searches, PAA questions, long-tail modifiers, question variants, intent modifiers).
2. **Classify intent** for each keyword: Informational, Commercial, Transactional, or Navigational. Remove navigational keywords from clustering.
3. **Compare SERPs** pairwise within intent groups. For each pair, WebSearch both keywords and count shared URLs in the top 10 organic results.
4. **Apply thresholds**: 7-10 shared URLs = same post, 4-6 = same cluster, 2-3 = interlink, 0-1 = separate.
5. **Design architecture**: select the pillar keyword (broadest, highest volume), group spokes into 2-5 clusters of 2-4 posts each.
6. **Build the link matrix**: mandatory (spoke-pillar bidirectional), recommended (spoke-spoke within cluster), optional (cross-cluster).
7. Before presenting results, run the pre-delivery validation checklist.

## Reference

### Reporting requirements

- The SERP overlap matrix (keyword pairs and scores).
- Cluster assignments with rationale.
- Template selection per post with intent justification.
- Complete internal link adjacency list.
- Cannibalization check results.

### Reference files

Load on demand for detailed methodology:

| File | Content |
|---|---|
| `skills/seo-cluster/references/serp-overlap-methodology.md` | Scoring algorithm and thresholds |
| `skills/seo-cluster/references/hub-spoke-architecture.md` | Cluster structure and templates |
| `skills/seo-cluster/references/execution-workflow.md` | Priority ordering and context injection |

### Cross-skill awareness

- If the user already has an `/seo plan` output, parse it for existing keyword research and competitive analysis. Do not duplicate that work.
- Content quality standards come from `seo-content` (E-E-A-T requirements).
- Schema markup templates for cluster pages are defined in `seo-schema`.

### Pre-delivery validation checklist

- [ ] No two posts share the same primary keyword.
- [ ] Every spoke has at least 3 incoming internal links planned.
- [ ] Every spoke links to the pillar (mandatory).
- [ ] Pillar links to every spoke (mandatory).
- [ ] No orphan pages in the link matrix.
- [ ] Template selection matches intent classification.
- [ ] Word count targets are within specification: pillar 2500-4000, spoke 1200-1800.
- [ ] Total cluster size is within constraints: 2-5 clusters, 2-4 posts each.
- [ ] SERP overlap data supports cluster groupings (no spoke with < 4 overlap to cluster peers).

## Output

Primary output is a `cluster-plan.json` file matching the schema in `skills/seo-cluster/references/hub-spoke-architecture.md`, plus a human-readable `cluster-plan.md` summary.

- findings file: `findings/cluster.md` — semantic clustering, cannibalization, pillar/spoke, and internal-link findings
- `audit-data.json` category: Content Architecture
