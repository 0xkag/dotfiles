---
name: glab-token-source
description: How to authenticate glab when its REST API calls return 401 —
source ~/.gitlab-token into the environment
metadata:
  node_type: memory
  type: reference
---

When `glab` REST API calls return `401 Unauthorized`, source the token file
into the environment first and glab works:

```
source ~/.gitlab-token
```

Suggest the user run `! source ~/.gitlab-token` so it executes in-session and
persists for subsequent `glab` calls.

Git operations over SSH are configured independently and work without this;
only the glab REST API needs the token. See [[glab-mr-review-comments]] and
[[gitlab-mr-dependencies]] for glab workflows that depend on a working API.
