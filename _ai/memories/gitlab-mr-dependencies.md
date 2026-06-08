---
name: gitlab-mr-dependencies
description: How to set cross-project GitLab MR merge dependencies
(blocked-by) via glab
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2c560b8d-566c-4256-a99d-647c33544fb7
---

GitLab **MR dependencies** ("blocked by", the cross-reference that gates merge
order) are a Premium feature and are **NOT settable via the REST API** — `PUT
/projects/:id/merge_requests/:iid` with `blocking_merge_request_ids` returns
HTTP 400 (the param isn't in the accepted list).

Set them via the **GraphQL mutation `mergeRequestSetBlockingMergeRequests`**.
Input fields: `projectPath` (ID), `iid` (String),
`blockingMergeRequestReferences` ([String!]! — MR reference strings, NOT
global IDs). For cross-project, use the full reference form
`group/sub/project!iid`.

The mutation is a **full set** (replaces the blocker list), and the MR being
updated is the one *blocked by* the listed references.

**Gotcha (cost me a silent failure):** passing repeated `-f refs=...` flags to
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

**Always verify** afterward (don't trust `errors: []`) by querying
`project(fullPath).mergeRequest(iid).blockingMergeRequests {
visibleMergeRequests { reference webUrl } hiddenCount }`.

Note: MR dependencies gate *merge* order only — they do NOT guarantee the
upstream change is *deployed* before the downstream MR's code runs. Call out
deploy-timing separately.
