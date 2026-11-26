---
name: gitlab-mr-dependencies
description: How to set cross-project GitLab MR merge dependencies
  (blocked-by) via glab, GraphQL mutation or REST blocks sub-resource, and
  how to verify them
metadata:
  node_type: memory
  type: reference
---

GitLab **MR dependencies** ("blocked by", the cross-reference that gates merge
order) are a Premium feature. `PUT /projects/:id/merge_requests/:iid` with
`blocking_merge_request_ids` returns HTTP 400 (the param isn't in the
accepted list); the REST way is the `blocks` sub-resource (below), and it is
also the reliable way to verify. Prefer it; the GraphQL mutation still works.

## REST: the `blocks` sub-resource (verified 2026-11-13)

`GET /projects/:id/merge_requests/:iid/blocks` lists the blockers of an MR,
each with `blocking_merge_request.references.full` and a block `id`.
`POST .../blocks` with `blocking_merge_request_id=<global numeric id of the
blocking MR>` adds one; that is the MR's `id` field (e.g. 123456789), NOT
its iid, read it from `GET /projects/:id/merge_requests/:iid`. It answers
HTTP 409 "Block already exists" when the blocker is already set.
`DELETE .../blocks/:block_id` removes one.

```
enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "group/sub/project")
glab api "projects/$enc/merge_requests/$IID/blocks"
glab api --method POST "projects/$enc/merge_requests/$IID/blocks" \
  -f blocking_merge_request_id=$BLOCKING_MR_ID
```

## GraphQL: `mergeRequestSetBlockingMergeRequests`
Input fields: `projectPath` (ID), `iid` (String),
`blockingMergeRequestReferences` ([String!]! — MR reference strings, NOT
global IDs). For cross-project, use the full reference form
`group/sub/project!iid`.

The mutation is a **full set** (replaces the blocker list), and the MR being
updated is the one *blocked by* the listed references.

**Gotcha (a silent failure):** passing repeated `-f refs=...` flags to
`glab api graphql` does NOT build an array — `glab` keeps only the LAST value,
so earlier references are silently dropped and the mutation still returns
`errors: []`. Use an **inline array literal** in the query string for multiple
blockers, e.g.:

```
glab api graphql -f query='mutation {
  mergeRequestSetBlockingMergeRequests(input:{
    projectPath:"group/proj",
    iid:"104",
    blockingMergeRequestReferences:["group/a!20","group/b!746"]
  }){ mergeRequest{iid} errors }
}'
```

**Always verify** afterward (don't trust `errors: []`), and verify with
REST `GET .../blocks` rather than with the standalone GraphQL query
`project(fullPath).mergeRequest(iid).blockingMergeRequests {
visibleMergeRequests { reference webUrl } hiddenCount }`. On 2026-11-13 that
query returned an empty list right after a mutation that answered
`errors: []`; a second identical mutation then returned the blocker in its
own `mergeRequest { blockingMergeRequests { visibleMergeRequests {
reference } } }` selection and REST GET showed it too. Whether the first
mutation failed silently or the query lagged is unknown, so: set, GET, and
repeat the mutation if GET is empty. Asking the mutation itself to return
`blockingMergeRequests` is the cheapest check.

Note: MR dependencies gate *merge* order only — they do NOT guarantee the
upstream change is *deployed* before the downstream MR's code runs. Call out
deploy-timing separately.
