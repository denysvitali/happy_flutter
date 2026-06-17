/// Domains that can invalidate the sync cache independently.
enum SyncDomain {
  sessions,
  messages,
  machines,
  settings,
  profile,
  artifacts,
  gitStatus,
  friendRequests,
  loops,
}
